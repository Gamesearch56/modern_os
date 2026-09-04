#!/usr/bin/env bash
# install.sh wires greetd_apply and skips non-login --target homes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-install-greetd: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-install-greetd: ok %s\n' "$*"; }

INSTALL="$ROOT/install/install.sh"
LIB="$ROOT/install/lib/greetd.sh"
[ -f "$INSTALL" ] && [ -f "$LIB" ] || { err "missing install.sh or greetd.sh"; exit 1; }

if grep -F 'source "$REPO_ROOT/install/lib/greetd.sh"' "$INSTALL" >/dev/null \
    && grep -F 'greetd_target_is_live_user' "$INSTALL" >/dev/null \
    && grep -F 'greetd_apply' "$INSTALL" >/dev/null; then
    ok "install.sh sources greetd.sh and calls greetd_apply"
else
    err "install.sh must source greetd.sh and apply on a login home"
fi

if grep -F 'greetd_apply "$USERNAME"' "$ROOT/install/system/provision-iso.sh" >/dev/null; then
    ok "provision-iso.sh calls the same greetd_apply"
else
    err "provision-iso.sh must call greetd_apply (one greeter path)"
fi

if grep -F 'would write' "$INSTALL" >/dev/null \
    && grep -F 'CONFIG_DIR/repo' "$INSTALL" >/dev/null; then
    ok "install.sh writes the clone pointer"
else
    err "install.sh must write \$TARGET/.config/modern/repo"
fi

if grep -F 'scripts/build-phylax.sh' "$INSTALL" >/dev/null; then
    ok "install.sh builds patched Phylax when cargo is present"
else
    err "install.sh must run scripts/build-phylax.sh so Confirm stays the session user"
fi

if grep -F 'capsLock' "$ROOT/scripts/wallpaper-sync.sh" >/dev/null \
    && grep -F 'weekday' "$ROOT/scripts/wallpaper-sync.sh" >/dev/null \
    && grep -F 'SessionUsers' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'getent' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionUsers.qml" >/dev/null; then
    ok "greeter snapshots i18n and lists users via getent"
else
    err "greeter must snapshot capsLock/weekday and list users via getent"
fi

if grep -F 'chmod 0664 /var/lib/modern/session/default-user' "$LIB" >/dev/null; then
    ok "default-user is group-writable so the greeter can remember the last account"
else
    err "default-user must be 0664 so greeter can update the last user"
fi

if grep -F 'kiosk.sh' "$LIB" >/dev/null \
    && grep -F '50-modern-greeter.rules' "$LIB" >/dev/null \
    && grep -F 'GREETD_SOCK' "$ROOT/install/system/greetd/kiosk.sh" >/dev/null \
    && grep -F 'GREETD_SOCK' "$ROOT/install/system/greetd/hyprland.lua" >/dev/null; then
    ok "greetd_apply installs the GREETD_SOCK kiosk"
else
    err "greetd_apply must install kiosk.sh, hyprland.lua GREETD_SOCK, and greeter polkit"
fi

export REPO_ROOT="$ROOT" LOG_FILE="/dev/null" DRY_RUN=1
# shellcheck source=../install/lib/log.sh
source "$ROOT/install/lib/log.sh"
# shellcheck source=../install/lib/ui.sh
source "$ROOT/install/lib/ui.sh"
# shellcheck source=../install/lib/greetd.sh
source "$LIB"

if greetd_target_is_live_user "/tmp/modern-greetd-skip-test"; then
    err "/tmp target must not count as a login home"
else
    ok "/tmp is not a login home"
fi
if greetd_target_is_live_user "$HOME"; then
    ok "this \$HOME is a login home"
else
    err "this \$HOME should be a login home"
fi

dry_out="$(greetd_apply "$(id -un)" 2>&1 || true)"
if printf '%s\n' "$dry_out" | grep -F 'would enable greetd.service' >/dev/null; then
    ok "dry-run lists greetd enable"
else
    err "greetd_apply DRY_RUN must list greetd enable"
fi

[ "$FAIL" -eq 0 ]
