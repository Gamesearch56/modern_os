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
cat >"$BIN/pkexec" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$TMP/pkexec.log"
for a in "\$@"; do [ -f "\$a" ] && cp "\$a" "$TMP/seen-plan"; done
exit "\$(cat "$TMP/pkexec-rc" 2>/dev/null || echo 0)"
EOF
cat >"$BIN/reload" <<EOF
#!/bin/sh
[ -f "$TMP/pkexec.log" ] && echo after-root >"$TMP/reloaded" || echo before-root >"$TMP/reloaded"
EOF
chmod +x "$BIN"/* "$HOME/.local/bin/phylax"
export PATH="$BIN:$PATH" MODERN_PKEXEC="$BIN/pkexec" MODERN_RELOAD_UI="$BIN/reload"
export MODERN_TEST_FIXTURE=1 MODERN_TEST_RUN_INSTALL=1 MODERN_DESKTOP_REPO="$CLONE" MODERN_DESKTOP_REMOTE="$REMOTE"

PLAN="$XDG_STATE_HOME/modern/root-plan"
MARKER="$XDG_STATE_HOME/modern/update-applied"
reset() { rm -f "$TMP/pkexec.log" "$TMP/seen-plan" "$TMP/reloaded" "$TMP/pkexec-rc" "$TMP/pkgs"; }
update() { "$MODERN" update </dev/null >"$TMP/out" 2>&1; }
wait_reload() {
    local _
    for _ in $(seq 1 20); do [ -f "$TMP/reloaded" ] && return 0; sleep 0.05; done
    return 1
}

reset
if update && grep -q -- '--snapshot --root-plan' "$TMP/pkexec.log" \
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
if ! update && [ -s "$PLAN" ] && [ ! -e "$MARKER" ] && ! wait_reload; then
    ok "cancelled auth keeps the plan and does not reload"
else
    err "cancelled pkexec must fail, keep the plan, skip reload"
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
echo 'mesa 1 -> 2' >"$TMP/pkgs"
if update && grep -q -- '--snapshot' "$TMP/pkexec.log" && ! grep -q -- '--root-plan' "$TMP/pkexec.log" \
    && ! wait_reload && [ ! -e "$MARKER" ]; then
    ok "package-only update: pkexec without plan, no reload"
else
    err "package-only update wrong: $(cat "$TMP/pkexec.log" 2>/dev/null)"
fi

reset
if update && [ ! -e "$TMP/pkexec.log" ] && ! wait_reload; then
    ok "nothing pending: no prompt, no reload"
else
    err "nothing pending must not prompt or reload"
fi

# shellcheck source=lib/pkg-name.sh
source "$ROOT/scripts/lib/pkg-name.sh"
# shellcheck source=lib/root-plan.sh
source "$ROOT/scripts/lib/root-plan.sh"
printf 'pkg good-pkg\npkg -Rdd\npkg ../x\nrm -rf /\ngreetd\n' >"$TMP/evil"
read_root_plan "$TMP/evil" 2>/dev/null
if [ "${ROOT_PLAN_PKGS[*]}" = good-pkg ] && [ "$ROOT_PLAN_GREETD" -eq 1 ]; then
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
unset MODERN_BIN

if (
    # shellcheck source=lib/update-guard.sh
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

for want in update_guard_detach update_guard_esp_backup snapper-restore.sh 'exit 3'; do
    grep -Fq "$want" "$ROOT/scripts/update-apply.sh" || err "update-apply.sh lacks $want"
done
grep -Fq 'update-run.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/Update.qml" \
    || err "Settings must run the update through update-run.sh"
grep -Fq 'vfat?' "$ROOT/iso/airootfs/etc/mkinitcpio.conf.d/50-modern-esp.conf" \
    || err "initramfs must carry the ESP driver"

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-update-apply: ok\n'
