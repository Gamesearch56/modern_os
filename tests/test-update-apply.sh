#!/usr/bin/env bash
# Simulates Settings → Update end to end without root or network:
# local release fixture, fake pkexec/checkupdates/reload. Asserts the
# root plan reaches the single pkexec, a cancelled prompt is retried,
# and the UI reload runs last with a marker for the reloaded shell.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODERN="$ROOT/scripts/modern"
FAIL=0
err() { printf 'test-update-apply: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-update-apply: ok %s\n' "$*"; }

[ -x "$ROOT/scripts/update-apply.sh" ] || err "update-apply.sh must be executable"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-upd-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
git_cfg() { git -c core.hooksPath=/dev/null -c user.email=t@e -c user.name=t "$@"; }

REMOTE="$TMP/remote.git"
CLONE="$TMP/clone"
git_cfg init -q --bare "$REMOTE"
git_cfg clone -q "$REMOTE" "$CLONE" 2>/dev/null
release() {
    mkdir -p "$CLONE/install"
    # Literal script body; expands when the fake install.sh runs.
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\nset -eu\n[ -n "${MODERN_ROOT_PLAN:-}" ] || exit 0\nprintf "pkg %s\\ngreetd\\n" "%s" >>"$MODERN_ROOT_PLAN"\n' \
        '%s' "$2" >"$CLONE/install/install.sh"
    chmod +x "$CLONE/install/install.sh"
    git_cfg -C "$CLONE" add -A
    git_cfg -C "$CLONE" commit -qm "$1"
    git_cfg -C "$CLONE" tag -a "$1" -m "$1"
    git_cfg -C "$CLONE" push -q origin HEAD:refs/heads/main "$1" 2>/dev/null
}
release v0.1.0 base
release v0.2.0 newpkg
git_cfg -C "$CLONE" checkout -q --detach v0.1.0

BIN="$TMP/bin"
mkdir -p "$BIN" "$TMP/home/.local/bin"
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" XDG_CONFIG_HOME="$TMP/cfg" XDG_RUNTIME_DIR="$TMP"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/phylax"
printf '#!/bin/sh\nexit 0\n' >"$BIN/systemctl"
printf '#!/bin/sh\n[ -f "%s/pkgs" ] && cat "%s/pkgs"\nexit 0\n' "$TMP" "$TMP" >"$BIN/checkupdates"
# Like update-apply.sh --wait: a cancelled prompt exits at once; an
# accepted one waits for "go" before it reads the root plan.
cat >"$BIN/pkexec" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$TMP/pkexec.log"
[ -f "$TMP/desk-at-prompt" ] || git -C "$CLONE" describe --tags --exact-match >"$TMP/desk-at-prompt" 2>/dev/null
rc="\$(cat "$TMP/pkexec-rc" 2>/dev/null || echo 0)"
[ "\$rc" -eq 0 ] || exit "\$rc"
prev=""
status=""
for a in "\$@"; do
    [ "\$prev" = --status-fifo ] && status="\$a"
    prev="\$a"
done
git -C "$CLONE" describe --tags --exact-match >"$TMP/tag-at-ready" 2>/dev/null || true
[ -z "\$status" ] || printf 'ready\n' >"\$status"
read -r go || go=""
echo "\$go" >"$TMP/gate"
[ "\$go" = go ] || exit 0
prev=""
for a in "\$@"; do
    [ "\$prev" = --root-plan ] && [ -s "\$a" ] && cp "\$a" "$TMP/seen-plan"
    prev="\$a"
done
exit 0
EOF
cat >"$BIN/reload" <<EOF
#!/bin/sh
[ -f "$TMP/pkexec.log" ] && echo after-root >"$TMP/reloaded" || echo before-root >"$TMP/reloaded"
EOF
chmod +x "$BIN"/* "$HOME/.local/bin/phylax"
# This machine may have snapper configured. Tests opt in by writing
# $BIN/snapper; the host binary must not count as installed.
mkdir -p "$TMP/masked-bin"
ln -s /usr/bin/* /bin/* "$TMP/masked-bin/" 2>/dev/null || true
rm -f "$TMP/masked-bin/snapper"
export PATH="$BIN:$TMP/masked-bin" MODERN_PKEXEC="$BIN/pkexec" MODERN_RELOAD_UI="$BIN/reload"
export MODERN_TEST_FIXTURE=1 MODERN_TEST_RUN_INSTALL=1 MODERN_DESKTOP_REPO="$CLONE" MODERN_DESKTOP_REMOTE="$REMOTE"

PLAN="$XDG_STATE_HOME/modern/root-plan"
MARKER="$XDG_STATE_HOME/modern/update-applied"
reset() { rm -f "$TMP/pkexec.log" "$TMP/seen-plan" "$TMP/reloaded" "$TMP/pkexec-rc" "$TMP/pkgs" "$TMP/gate" "$TMP/desk-at-prompt"; }
update() { "$MODERN" update </dev/null >"$TMP/out" 2>&1; }
wait_reload() {
    local _
    for _ in $(seq 1 20); do [ -f "$TMP/reloaded" ] && return 0; sleep 0.05; done
    return 1
}

reset
if update && grep -q -- '--snapshot --wait --root-plan' "$TMP/pkexec.log" \
    && grep -qx 'pkg newpkg' "$TMP/seen-plan" && grep -qx greetd "$TMP/seen-plan"; then
    ok "release root needs reach one pkexec (snapshot + root plan)"
else
    err "root plan not passed to pkexec: $(cat "$TMP/out" "$TMP/pkexec.log" 2>/dev/null)"
fi
[ ! -e "$PLAN" ] || err "root plan kept after a successful root step"
if wait_reload && [ "$(cat "$TMP/reloaded")" = after-root ] && [ "$(cat "$MARKER")" = v0.2.0 ]; then
    ok "UI reload runs after the root step; marker names v0.2.0"
else
    err "reload/marker wrong: $(cat "$TMP/reloaded" "$MARKER" 2>/dev/null)"
fi
[ "$(git -C "$CLONE" describe --tags --exact-match)" = v0.2.0 ] || err "checkout not on v0.2.0"

if [ "$("$MODERN" update-notice)" = v0.2.0 ] && [ -z "$("$MODERN" update-notice)" ]; then
    ok "update-notice reports once after the reload"
else
    err "update-notice must print the version once"
fi

reset
release v0.3.0 otherpkg
git_cfg -C "$CLONE" checkout -q --detach v0.2.0
echo 126 >"$TMP/pkexec-rc"
rc=0
update || rc=$?
if [ "$rc" -eq 4 ] && grep -q 'password prompt was cancelled' "$TMP/out" \
    && [ -s "$PLAN" ] && [ ! -e "$MARKER" ] && ! wait_reload; then
    ok "cancelled auth exits 4 with a message, keeps the plan and does not reload"
else
    err "cancelled pkexec must exit 4 (got $rc), keep the plan, skip reload: $(cat "$TMP/out")"
fi
reset
if update && grep -qx 'pkg otherpkg' "$TMP/seen-plan" && [ ! -e "$PLAN" ] \
    && wait_reload && [ "$(cat "$MARKER")" = v0.3.0 ]; then
    ok "next update retries the kept plan, then reloads"
else
    err "retry failed: $(cat "$TMP/out" 2>/dev/null)"
fi
"$MODERN" update-notice >/dev/null

reset
release v0.4.0 thirdpkg
git_cfg -C "$CLONE" checkout -q --detach v0.3.0
echo 'mesa 1 -> 2' >"$TMP/pkgs"
if update && [ "$(cat "$TMP/desk-at-prompt")" = v0.3.0 ] && [ "$(cat "$TMP/gate")" = go ] \
    && grep -qx 'pkg thirdpkg' "$TMP/seen-plan" && [ "$(grep -c . "$TMP/pkexec.log")" -eq 1 ] \
    && wait_reload && [ "$(cat "$MARKER")" = v0.4.0 ]; then
    ok "packages pending: the one prompt comes before the release, which then hands over its plan"
else
    err "prompt not first: at=$(cat "$TMP/desk-at-prompt" 2>/dev/null) gate=$(cat "$TMP/gate" 2>/dev/null) $(cat "$TMP/out")"
fi
"$MODERN" update-notice >/dev/null

reset
echo 'mesa 1 -> 2' >"$TMP/pkgs"
if update && grep -q -- '--snapshot' "$TMP/pkexec.log" && [ ! -e "$TMP/seen-plan" ] \
    && ! wait_reload && [ ! -e "$MARKER" ]; then
    ok "package-only update: pkexec without plan, no reload"
else
    err "package-only update wrong: plan=$([ -e "$TMP/seen-plan" ] && echo seen) reload=$(cat "$TMP/reloaded" 2>/dev/null) marker=$(cat "$MARKER" 2>/dev/null) $(cat "$TMP/out")"
fi

reset
printf '#!/bin/sh\nexit 1\n' >"$BIN/snapper"
chmod +x "$BIN/snapper"
echo 'mesa 1 -> 2' >"$TMP/pkgs"
if update && ! grep -F 'Creating snapper snapshot' "$TMP/out" \
    && ! grep -F 'Erstelle Snapper-Snapshot' "$TMP/out"; then
    ok "no snapshot line when snapper cannot take one"
else
    err "update log claimed a snapper snapshot: $(cat "$TMP/out")"
fi
rm -f "$BIN/snapper"

reset
release v0.5.0 fifthpkg
git_cfg -C "$CLONE" checkout -q --detach v0.4.0
printf '#!/bin/sh\nprintf "root\\n"\nexit 0\n' >"$BIN/snapper"
chmod +x "$BIN/snapper"
echo 5 >"$TMP/pkexec-rc"
export MODERN_UPDATE_PROGRESS=1
rc=0
update || rc=$?
if [ "$rc" -eq 5 ] && [ "$(git_cfg -C "$CLONE" describe --tags --exact-match)" = v0.4.0 ] \
    && ! grep -q '@@progress desktop' "$TMP/out"; then
    ok "a failed snapshot stops the update before it is logged and keeps its exit status"
else
    err "update continued before the snapshot could finish: $(cat "$TMP/out" 2>/dev/null)"
fi
unset MODERN_UPDATE_PROGRESS
rm -f "$TMP/pkexec-rc" "$BIN/snapper"

reset
printf '#!/bin/sh\nprintf "root\\n"\nexit 0\n' >"$BIN/snapper"
chmod +x "$BIN/snapper"
export MODERN_UPDATE_PROGRESS=1
if update && [ "$(cat "$TMP/tag-at-ready" 2>/dev/null)" = v0.4.0 ] \
    && [ "$(git_cfg -C "$CLONE" describe --tags --exact-match)" = v0.5.0 ] \
    && grep -q '@@progress desktop' "$TMP/out"; then
    ok "with snapper installed, the release is logged only after the privileged step is ready"
else
    err "release was logged before ready: at=$(cat "$TMP/tag-at-ready" 2>/dev/null) $(cat "$TMP/out" 2>/dev/null)"
fi
unset MODERN_UPDATE_PROGRESS
rm -f "$BIN/snapper"
"$MODERN" update-notice >/dev/null || true

reset
if update && [ ! -e "$TMP/pkexec.log" ] && ! wait_reload; then
    ok "nothing pending: no prompt, no reload"
else
    err "nothing pending must not prompt or reload"
fi

# shellcheck source=../scripts/lib/pkg-name.sh
source "$ROOT/scripts/lib/pkg-name.sh"
# shellcheck source=../scripts/lib/root-plan.sh
source "$ROOT/scripts/lib/root-plan.sh"
printf 'pkg good-pkg\npkg -Rdd\npkg ../x\nrm -rf /\ngreetd\nsplash\nmirrors\nnope\n' >"$TMP/evil"
read_root_plan "$TMP/evil" 2>/dev/null
if [ "${ROOT_PLAN_PKGS[*]}" = good-pkg ] && [ "$ROOT_PLAN_GREETD" -eq 1 ] \
    && [ "$ROOT_PLAN_SPLASH" -eq 1 ] && [ "$ROOT_PLAN_MIRRORS" -eq 1 ]; then
    ok "root plan keeps only valid package names"
else
    err "root plan parsed: ${ROOT_PLAN_PKGS[*]}"
fi
if grep -Fq 'assert_root_plan_file' "$ROOT/scripts/update-apply.sh" \
    && grep -Fq 'assert_root_plan_file' "$ROOT/scripts/lib/root-plan.sh"; then
    ok "update-apply verifies root-plan owner and path"
else
    err "update-apply must call assert_root_plan_file"
fi

# shellcheck disable=SC2016
printf '#!/bin/sh\n[ "$1" = -T ] && echo missing-one\nexit 127\n' >"$BIN/pacman"
chmod +x "$BIN/pacman"
if (
    REPO_ROOT="$ROOT" LOG_FILE=/dev/null DRY_RUN=0 MODERN_ROOT_PLAN="$TMP/defer"
    # shellcheck source=../install/lib/log.sh
    source "$ROOT/install/lib/log.sh"
    # shellcheck source=../install/lib/pkg.sh
    source "$ROOT/install/lib/pkg.sh"
    install_native present missing-one >/dev/null
) && [ "$(cat "$TMP/defer")" = "pkg missing-one" ]; then
    ok "install.sh without a terminal defers missing packages, no sudo"
else
    err "install_native did not defer to the plan"
fi

RUN="$ROOT/scripts/update-run.sh"
cat >"$BIN/fake-modern" <<EOF
#!/bin/sh
echo "(1/2) upgrading a"
sleep 1
echo "(2/2) upgrading b"
exit "\$(cat "$TMP/modern-rc" 2>/dev/null || echo 0)"
EOF
chmod +x "$BIN/fake-modern"
export MODERN_BIN="$BIN/fake-modern"
rm -f "$TMP/modern-rc"
"$RUN" start >"$TMP/follow" 2>&1 &
follower=$!
sleep 0.3
kill -9 "$follower" 2>/dev/null || true
wait "$follower" 2>/dev/null || true
sleep 1.5
rc=0
"$RUN" attach >"$TMP/attach" 2>&1 || rc=$?
if [ "$rc" -eq 0 ] && grep -q '(2/2) upgrading b' "$XDG_STATE_HOME/modern/update.log" \
    && grep -q '(2/2)' "$TMP/attach"; then
    ok "update outlives a killed shell follower; attach reports the result"
else
    err "detached update: rc=$rc $(cat "$TMP/attach" "$XDG_STATE_HOME/modern/update.log" 2>/dev/null)"
fi
rc=0
"$RUN" attach >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 75 ]; then
    ok "attach with nothing running exits 75"
else
    err "attach after report gave $rc"
fi
echo 3 >"$TMP/modern-rc"
rc=0
"$RUN" start >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 3 ]; then
    ok "start passes the update's exit status through"
else
    err "start rc $rc"
fi
if [ -s "$XDG_STATE_HOME/modern/update.log.1" ]; then
    ok "the previous update's log is kept as update.log.1"
else
    err "start must keep the previous log as update.log.1"
fi

# Two starts at once (two Settings windows): one update, both follow it.
printf '#!/bin/sh
echo run >>"%s/runs"
sleep 1
exit 0
' "$TMP" >"$BIN/fake-modern"
rm -f "$TMP/runs"
"$RUN" start >/dev/null 2>&1 &
first=$!
"$RUN" start >/dev/null 2>&1 &
second=$!
rc_a=0
rc_b=0
wait "$first" || rc_a=$?
wait "$second" || rc_b=$?
if [ "$(wc -l <"$TMP/runs")" -eq 1 ] && [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 0 ]; then
    ok "a second start follows the running update instead of starting another"
else
    err "two starts ran $(wc -l <"$TMP/runs") updates (rc $rc_a/$rc_b)"
fi

# Power loss or a killed session: a pid file, no result, nothing running.
rm -f "$XDG_STATE_HOME/modern/update.rc"
echo 999999 >"$XDG_STATE_HOME/modern/update.pid"
rc=0
"$RUN" attach >"$TMP/attach" 2>&1 || rc=$?
if [ "$rc" -eq 9 ] && grep -q 'stopped before it finished' "$TMP/attach"; then
    ok "an update cut off without a result is reported as stopped"
else
    err "stopped update: rc=$rc $(cat "$TMP/attach")"
fi
rc=0
"$RUN" attach >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 75 ] || err "a reported stopped update must not be reported twice (rc $rc)"

# A release leaves the UI restart to Settings, which runs `reload` after
# showing 100%. A shell that starts after the update already runs it.
# shellcheck disable=SC2016
printf '#!/bin/sh\n: >"$MODERN_UPDATE_DEFER_RELOAD"\n' >"$BIN/fake-modern"
printf '#!/bin/sh\n: >"%s/reloaded"\n' "$TMP" >"$BIN/fake-reload"
chmod +x "$BIN/fake-modern" "$BIN/fake-reload"
pending="$XDG_STATE_HOME/modern/reload-pending"
"$RUN" start >/dev/null 2>&1 || true
if [ -f "$pending" ]; then
    MODERN_RELOAD_UI="$BIN/fake-reload" "$RUN" reload
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -f "$TMP/reloaded" ] && break
        sleep 0.1
    done
fi
if [ -f "$TMP/reloaded" ] && [ ! -f "$pending" ]; then
    ok "the UI restart waits for Settings and runs once"
else
    err "deferred reload did not run through update-run.sh reload"
fi
: >"$pending"
echo 0 >"$XDG_STATE_HOME/modern/update.rc"
"$RUN" attach >/dev/null 2>&1 || true
[ ! -f "$pending" ] || err "a shell started after the update must not reload again"
unset MODERN_BIN

# The unit's output reaches the caller in full, even what pacman prints
# in its last moment, and its exit status comes back.
if [ -d /run/systemd/system ]; then
    DBIN="$TMP/detach-bin"
    mkdir -p "$DBIN"
    # shellcheck disable=SC2016
    printf '#!/bin/sh\n[ "$1" = is-active ] && exit 1\nexit 0\n' >"$DBIN/systemctl"
    cat >"$DBIN/systemd-run" <<'EOF'
#!/bin/sh
out=""
while [ $# -gt 0 ]; do
    case "$1" in
        --property=StandardOutput=append:*) out="${1#--property=StandardOutput=append:}" ;;
        --) shift; break ;;
    esac
    shift
done
"$@" >>"$out" 2>&1
EOF
    # shellcheck disable=SC2016
    printf '#!/bin/sh\nwhile [ "${1#--}" != "$1" ]; do shift; done\nexec "$@"\n' >"$DBIN/systemd-inhibit"
    printf '#!/bin/sh\necho first\nsleep 0.5\necho last\nexit 4\n' >"$DBIN/job"
    chmod +x "$DBIN"/*
    rc=0
    out="$(
        unset MODERN_UPDATE_UNIT
        # shellcheck source=../scripts/lib/update-guard.sh
        source "$ROOT/scripts/lib/update-guard.sh"
        UPDATE_OUT="$TMP/unit.log" PATH="$DBIN:$PATH" update_guard_detach "$DBIN/job"
    )" || rc=$?
    if [ "$rc" -eq 4 ] && [ "$out" = "$(printf 'first\nlast')" ]; then
        ok "the system step's output arrives complete with its exit status"
    else
        err "detach gave rc=$rc output='$out'"
    fi
fi

dblock="$TMP/db.lck"
: >"$dblock"
if (
    # shellcheck source=../scripts/lib/update-guard.sh
    source "$ROOT/scripts/lib/update-guard.sh"
    UPDATE_PACMAN_LOCK="$dblock" update_guard_pacman_lock >/dev/null
) && [ ! -e "$dblock" ]; then
    ok "a pacman lock nobody holds is removed"
else
    err "a stale pacman lock must be removed"
fi
: >"$dblock"
(
    exec 7<"$dblock"
    sleep 30
) &
holder=$!
# The checker looks at open fds. Wait until this holder has the lock,
# or a busy machine removes it as stale before the fd exists.
held=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    for fd in /proc/"$holder"/fd/*; do
        [ "$(readlink "$fd" 2>/dev/null || true)" = "$dblock" ] && held=1
    done
    [ "$held" -eq 1 ] && break
    sleep 0.05
done
if (
    # shellcheck source=../scripts/lib/update-guard.sh
    source "$ROOT/scripts/lib/update-guard.sh"
    ! UPDATE_PACMAN_LOCK="$dblock" update_guard_pacman_lock
) && [ -e "$dblock" ]; then
    ok "a pacman lock held by a running program stops the update"
else
    err "a held pacman lock must stop the update and stay"
fi
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true

finish_line="$(grep -n '^progress finish' "$ROOT/scripts/update-apply.sh" | tail -1 | cut -d: -f1)"
# shellcheck disable=SC2016
greetd_line="$(grep -n 'greetd_apply "\$user"' "$ROOT/scripts/update-apply.sh" | cut -d: -f1)"
if [ -n "$finish_line" ] && [ -n "$greetd_line" ] && [ "$finish_line" -gt "$greetd_line" ]; then
    ok "100% comes after the release's own root steps"
else
    err "progress finish must follow the root plan steps"
fi
for k in cancelled snapshot release packages partial stopped locked releaseStep; do
    for lang in en de; do
        jq -e --arg k "$k" '.settings.update.fail[$k] | length > 0' \
            "$ROOT/stow/modern/.config/modern/translations/$lang.json" >/dev/null \
            || err "$lang.json lacks settings.update.fail.$k"
    done
    grep -Fq "\"$k\"" "$ROOT/stow/shell/.config/quickshell/modern/Services/UpdateClassify.qml" \
        || err "UpdateClassify.failureText does not map $k"
done

if (
    # shellcheck source=../scripts/lib/update-guard.sh
    source "$ROOT/scripts/lib/update-guard.sh"
    UPDATE_PACMAN_LOG="$TMP/pacman.log"
    printf '[ALPM] transaction completed\n' >"$UPDATE_PACMAN_LOG"
    mark="$(update_guard_log_mark)"
    printf '[ALPM] transaction started\n[ALPM] upgraded linux-zen\n' >>"$UPDATE_PACMAN_LOG"
    update_guard_partial "$mark" || exit 1
    printf '[ALPM] transaction completed\n' >>"$UPDATE_PACMAN_LOG"
    ! update_guard_partial "$mark" || exit 1
    mark="$(update_guard_log_mark)"
    printf '[PACMAN] error: failed retrieving file\n' >>"$UPDATE_PACMAN_LOG"
    ! update_guard_partial "$mark"
); then
    ok "a half-applied transaction is told apart from an early failure"
else
    err "update_guard_partial misreads pacman.log"
fi

for want in update_guard_detach update_guard_esp_backup update_guard_pacman_lock snapper-restore.sh \
    'fail 3' 'fail 5' 'fail 7' 'fail 8' 'fail 10' 'fail 11' 'STEP_RC=11'; do
    grep -Fq "$want" "$ROOT/scripts/update-apply.sh" || err "update-apply.sh lacks $want"
done
grep -Fq 'update-run.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/Update.qml" \
    || err "Settings must run the update through update-run.sh"
grep -Fq 'UpdateBoot.arm' "$ROOT/stow/shell/.config/quickshell/modern/shell.qml" \
    || err "the shell must check for updates once the session is up"
grep -Fq 'availableNotice' "$ROOT/stow/shell/.config/quickshell/modern/Services/UpdateClassify.qml" \
    || err "an available ModernOS version needs its own notice"
if ! grep -Fq 'desktopAvailable' "$ROOT/stow/modern/.config/modern/translations/en.json" \
    || ! grep -Fq 'desktopAvailable' "$ROOT/stow/modern/.config/modern/translations/de.json"; then
    err "desktopAvailable must exist in both translations"
fi
if ! grep -Fq '"desktopBanner": "A new ModernOS version is available"' "$ROOT/stow/modern/.config/modern/translations/en.json" \
    || ! grep -Fq '"desktopBanner": "Eine neue ModernOS-Version ist verfügbar"' "$ROOT/stow/modern/.config/modern/translations/de.json" \
    || ! grep -Fq 'settings.update.desktopBanner' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/system/Status.qml"; then
    err "the update status line must only name a waiting ModernOS release"
fi
if ! grep -Fq 'availableOne' "$ROOT/stow/modern/.config/modern/translations/en.json" \
    || ! grep -Fq '"availableOne": "1 Update verfügbar"' "$ROOT/stow/modern/.config/modern/translations/de.json" \
    || ! grep -Fq 'settings.update.availableOne' "$ROOT/stow/shell/.config/quickshell/modern/Services/UpdateClassify.qml"; then
    err "one pending update must use the singular notice"
fi
if ! grep -Fq 'root.restarting = (root._ran' "$ROOT/stow/shell/.config/quickshell/modern/Services/Update.qml"; then
    err "a package update must not wait on a UI restart"
fi
if ! grep -Fq 'closeTimer.restart(); root.refresh(true)' "$ROOT/stow/shell/.config/quickshell/modern/Services/Update.qml"; then
    err "a finished update must search again inside the quiet period"
fi
if ! grep -Fq 'settings.update.desktopApplied' "$ROOT/stow/shell/.config/quickshell/modern/Services/Update.qml" \
    || ! grep -Fq 'desktopAppliedBody' "$ROOT/stow/modern/.config/modern/translations/en.json" \
    || ! grep -Fq 'desktopAppliedBody' "$ROOT/stow/modern/.config/modern/translations/de.json"; then
    err "a finished ModernOS update must toast the new version after reload"
fi
grep -Fq 'inhibitReloadPopup' "$ROOT/stow/shell/.config/quickshell/modern/shell.qml" \
    || err "Quickshell's own reload popup must stay hidden"
if ! grep -Fq 'Notifications.dismissAll()' "$ROOT/stow/shell/.config/quickshell/modern/shell.qml" \
    || ! grep -Fq 'notification.lastGeneration' "$ROOT/stow/shell/.config/quickshell/modern/Services/Notifications.qml"; then
    err "a reload must clear notifications so their banners do not return"
fi
grep -Fq 'clear_hypr_reload_banner' "$ROOT/scripts/reload-ui.sh" \
    || err "reload-ui must dismiss Hyprland's error bar after a clean reload"
qs_line="$(grep -n 'ipc call shell reload' "$ROOT/scripts/reload-ui.sh" | head -1 | cut -d: -f1)"
idle_line="$(grep -n 'hypridle-apply.sh' "$ROOT/scripts/reload-ui.sh" | head -1 | cut -d: -f1)"
if [ -n "$qs_line" ] && [ -n "$idle_line" ] && [ "$qs_line" -lt "$idle_line" ]; then
    ok "Quickshell restarts before the slower compositor steps"
else
    err "Quickshell reload must run before hypridle so Settings does not wait on the finished update"
fi
grep -Fq 'vfat?' "$ROOT/iso/airootfs/etc/mkinitcpio.conf.d/50-modern-esp.conf" \
    || err "initramfs must carry the ESP driver"

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-update-apply: ok\n'
