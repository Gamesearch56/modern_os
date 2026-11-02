#!/usr/bin/env bash
# Privileged restore of a Snapper root snapshot. fstab mounts subvol=/@,
# so `snapper rollback` would not change the next boot — this replaces
# @ with a read-write clone of the chosen snapshot. @home / @pkg / @log
# / @swap / @snapshots stay. The previous @ is kept as @rollback-UTC.
# Settings reboots after a successful run. Fixture env is ignored as root.
set -euo pipefail

die() { printf 'snapper-restore: ERROR: %s\n' "$*" >&2; exit 1; }

NUM="${1:-}"
[[ "$NUM" =~ ^[1-9][0-9]*$ ]] || die "usage: snapper-restore.sh <number>"
[ "$#" -eq 1 ] || die "usage: snapper-restore.sh <number>"

ROOT=""
FIXTURE=0
if [ "$(id -u)" -ne 0 ] && [ "${MODERN_TEST_FIXTURE:-}" = "1" ] \
    && [ -n "${MODERN_RESTORE_ROOT:-}" ]; then
    ROOT="${MODERN_RESTORE_ROOT}"
    FIXTURE=1
fi

clone_to() {
    local src="$1" dst="$2"
    if [ "$FIXTURE" -eq 1 ]; then
        mkdir -p "$dst"
        cp -a "$src/." "$dst/"
        return
    fi
    btrfs subvolume snapshot "$src" "$dst" >/dev/null
}

drop_new() {
    local path="$1"
    [ -e "$path" ] || return 0
    if [ "$FIXTURE" -eq 1 ]; then
        rm -rf "$path"
        return
    fi
    btrfs subvolume delete "$path" >/dev/null
}

if [ "$FIXTURE" -eq 1 ]; then
    [ -d "$ROOT" ] || die "fixture root missing"
else
    [ "$(id -u)" -eq 0 ] || die "must run as root (pkexec)"
    [ "$(findmnt -no FSTYPE /)" = btrfs ] || die "root is not btrfs"
    local_dev="$(findmnt -no SOURCE /)"
    local_dev="${local_dev%%\[*}"
    [ -n "$local_dev" ] || die "could not find the btrfs device"
    ROOT="/run/modern-restore"
    mkdir -p "$ROOT"
    if findmnt -n "$ROOT" >/dev/null 2>&1; then
        umount "$ROOT" || die "could not free $ROOT"
    fi
    mount -o subvolid=5 "$local_dev" "$ROOT"
    trap 'umount "$ROOT" 2>/dev/null || true' EXIT
fi

[ -d "$ROOT/@" ] || die "subvolume @ missing"
[ -d "$ROOT/@home" ] || die "subvolume @home missing"
[ -d "$ROOT/@snapshots" ] || die "subvolume @snapshots missing"

SRC="$ROOT/@snapshots/$NUM/snapshot"
INFO="$ROOT/@snapshots/$NUM/info.xml"
[ -d "$SRC" ] || die "snapshot $NUM not found"
[ -f "$INFO" ] || die "snapshot $NUM has no info.xml"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OLD="@rollback-${STAMP}"
if [ -e "$ROOT/$OLD" ]; then
    OLD="@rollback-${STAMP}-$$"
fi
[ ! -e "$ROOT/$OLD" ] || die "rollback name exists"

NEW="$ROOT/@.restore-new"
drop_new "$NEW"
clone_to "$SRC" "$NEW"
[ -d "$NEW" ] || die "clone failed"

mv "$ROOT/@" "$ROOT/$OLD"
mv "$NEW" "$ROOT/@"

[ -d "$ROOT/@" ] || die "restored @ missing"
[ -d "$ROOT/@home" ] || die "@home missing after restore"
[ -d "$ROOT/$OLD" ] || die "previous @ was not kept"

# The restored modules only load under the kernel that was on the ESP
# when the snapshot was taken (update-guard.sh copies it into @).
ESP_COPY="$ROOT/@/var/lib/modern/esp"
ESP=/boot
if [ "$FIXTURE" -eq 1 ]; then
    ESP="${MODERN_RESTORE_ESP:-}"
elif [ "$(findmnt -no FSTYPE /boot 2>/dev/null)" != vfat ]; then
    ESP=""
fi
if [ -d "$ESP_COPY" ] && [ -n "$ESP" ] && [ -d "$ESP" ]; then
    rsync -rt --delete --exclude='/EFI/' --exclude='/System Volume Information/' \
        "$ESP_COPY/" "$ESP/" || die "could not restore /boot from snapshot $NUM"
    printf 'snapper-restore: /boot restored from snapshot %s\n' "$NUM"
fi
