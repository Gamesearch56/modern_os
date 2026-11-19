#!/usr/bin/env bash
# Root-side safety for update-apply.sh. Source only.
#
# A pacman transaction cut off halfway leaves /usr/lib/modules without
# the kernel that is still on the ESP, so the next boot cannot even
# mount /boot. Three guards:
#   - update_guard_detach: the root step runs as a transient system
#     service, so neither a crashed shell (SIGPIPE on its pipe) nor a
#     lost session can kill pacman. Shutdown and sleep are inhibited.
#   - update_guard_esp_backup: the ESP is mirrored into the root
#     filesystem before the snapshot, so a restore brings back a kernel
#     that matches the restored modules (snapper-restore.sh).
#   - update_guard_partial: tells a failed run that changed the system
#     from one that failed before the first package was touched.

UPDATE_UNIT="modern-system-update"
UPDATE_ESP_COPY="/var/lib/modern/esp"
# Read by update-apply.sh, which sources this file.
# shellcheck disable=SC2034
UPDATE_MARK="/var/lib/modern/update-snapshot"
UPDATE_PACMAN_LOG="${UPDATE_PACMAN_LOG:-/var/log/pacman.log}"

# Re-runs "$@" inside the system service and streams its journal.
# Returns the service's exit status. No-op (returns 255) inside the unit
# or without systemd.
update_guard_detach() {
    [ -z "${MODERN_UPDATE_UNIT:-}" ] || return 255
    [ -d /run/systemd/system ] && command -v systemd-run >/dev/null 2>&1 || return 255
    if systemctl is-active --quiet "$UPDATE_UNIT" 2>/dev/null; then
        printf 'update-apply: a system update is already running\n' >&2
        return 1
    fi
    systemctl reset-failed "$UPDATE_UNIT" >/dev/null 2>&1 || true
    # A file, not the journal: journald lags the unit, and a follower cut
    # off after a fixed wait dropped pacman's last lines. tail --pid
    # reads to the end once systemd-run has returned.
    local out="${UPDATE_OUT:-/run/$UPDATE_UNIT.log}" runner rc=0
    install -m 0644 /dev/null "$out"
    systemd-run --quiet --wait --collect --service-type=exec \
        --unit="$UPDATE_UNIT" --description="ModernOS system update" \
        --property=StandardOutput="append:$out" --property=StandardError="append:$out" \
        --setenv=MODERN_UPDATE_UNIT=1 \
        --setenv=MODERN_SNAPSHOT_ID="${MODERN_SNAPSHOT_ID:-}" \
        --setenv=PKEXEC_UID="${PKEXEC_UID:-}" --setenv=SUDO_UID="${SUDO_UID:-}" \
        -- systemd-inhibit --what=shutdown:sleep:idle --mode=block \
        --who=ModernOS --why="System update" "$@" &
    runner=$!
    tail -n +1 -F --pid="$runner" "$out" 2>/dev/null || true
    wait "$runner" || rc=$?
    return "$rc"
}

# Mirrors the ESP (minus firmware vendor dirs) into the root filesystem.
update_guard_esp_backup() {
    local esp
    esp="$(findmnt -no TARGET --target /boot 2>/dev/null || true)"
    [ "$esp" = /boot ] || return 0
    [ "$(findmnt -no FSTYPE /boot)" = vfat ] || return 0
    mkdir -p "$UPDATE_ESP_COPY"
    rsync -rt --delete --exclude='/EFI/' --exclude='/System Volume Information/' \
        /boot/ "$UPDATE_ESP_COPY/"
}

# Byte offset of pacman.log, to check only this run's lines afterwards.
update_guard_log_mark() {
    stat -c %s "$UPDATE_PACMAN_LOG" 2>/dev/null || printf '0\n'
}

# True when pacman started committing after offset $1 and did not finish.
update_guard_partial() {
    local since="$1" tail
    tail="$(tail -c +"$((since + 1))" "$UPDATE_PACMAN_LOG" 2>/dev/null || true)"
    printf '%s\n' "$tail" | grep -q '\[ALPM\] transaction started' || return 1
    ! printf '%s\n' "$tail" | grep -q '\[ALPM\] transaction completed'
}

# Number of the newest root snapshot with our description, or empty.
update_guard_last_snapshot() {
    snapper -c root --csvout list --columns number,description 2>/dev/null \
        | awk -F, '$2 == "ModernOS Update" { n = $1 } END { if (n) print n }'
}
