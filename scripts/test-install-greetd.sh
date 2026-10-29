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

if grep -F "source \"\$REPO_ROOT/install/lib/greetd.sh\"" "$INSTALL" >/dev/null \
    && grep -F 'greetd_target_is_live_user' "$INSTALL" >/dev/null \
    && grep -F 'greetd_apply' "$INSTALL" >/dev/null \
    && grep -F 'skipping greetd (dotfiles-only)' "$INSTALL" >/dev/null \
    && grep -F 'skipping theme-apply' "$INSTALL" >/dev/null; then
    ok "install.sh sources greetd.sh and calls greetd_apply"
else
    err "install.sh must source greetd.sh and apply on a login home"
fi

if grep -F "greetd_apply \"\$USERNAME\"" "$ROOT/install/system/provision-iso.sh" >/dev/null; then
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

if grep -F 'capsLock' "$ROOT/scripts/session-chrome-sync.sh" >/dev/null \
    && grep -F 'weekday' "$ROOT/scripts/session-chrome-sync.sh" >/dev/null \
    && grep -F 'session-chrome-sync.sh' "$ROOT/scripts/wallpaper-sync.sh" >/dev/null \
    && grep -F 'session-keyboard-sync.sh' "$ROOT/scripts/wallpaper-sync.sh" >/dev/null \
    && grep -F 'session-monitors-sync.sh' "$ROOT/scripts/wallpaper-sync.sh" >/dev/null \
    && grep -F 'keyboard.json' "$ROOT/install/system/greetd/hyprland.lua" >/dev/null \
    && grep -F 'SessionUsers' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'modern-users.json' "$ROOT/install/system/greetd/kiosk.sh" >/dev/null \
    && grep -F 'monitors.json' "$ROOT/install/system/greetd/hyprland.lua" >/dev/null \
    && grep -F 'sessionUsers' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'sessionAuth' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'property var accounts' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionUsers.qml" >/dev/null \
    && grep -F '/etc/passwd' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionUsers.qml" >/dev/null; then
    ok "greeter snapshots i18n, keyboard, users, and monitor HDR profiles"
else
    err "greeter must snapshot chrome.json, keyboard.json, users.json, and monitors.json"
fi

SURF="$ROOT/stow/greeter/.config/quickshell/greeter/SessionSurface.qml"
if grep -F 'id: overlay' "$SURF" >/dev/null \
    && ! grep -E '^[[:space:]]+id: chrome$' "$SURF" >/dev/null \
    && ! grep -RIn --include='*.qml' 'font.families' "$ROOT/stow/greeter" >/dev/null; then
    ok "greeter overlay does not shadow SessionChrome"
else
    err "SessionSurface overlay must not use id chrome; greeter Text must use font.family"
fi

if grep -F 'chmod 0664 /var/lib/modern/session/default-user' "$LIB" >/dev/null; then
    ok "default-user is group-writable so the greeter can remember the last account"
else
    err "default-user must be 0664 so greeter can update the last user"
fi

if python3 "$ROOT/install/system/greetd/list-users.py" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d, list); assert all("home" in x and "value" in x for x in d)' >/dev/null; then
    ok "list-users.py emits a JSON array"
else
    err "list-users.py must print a JSON array of login names with home"
fi

if grep -F 'SessionAvatar' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionIdentity.qml" >/dev/null \
    && grep -F 'faces' "$ROOT/scripts/session-users-sync.sh" >/dev/null; then
    ok "greeter shows a round face above the user select"
else
    err "greeter SessionIdentity must include SessionAvatar and snapshot faces"
fi

if grep -F '_raise' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionSelect.qml" >/dev/null \
    && grep -F 'HoverHandler' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionSelectMenu.qml" >/dev/null \
    && grep -F 'primaryContainer' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionSelectMenu.qml" >/dev/null \
    && grep -F 'iconMd' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionSelect.qml" >/dev/null; then
    ok "user select menu stacks above the password field and has hover"
else
    err "SessionSelect must raise z while open, hover menu rows, and use iconMd for the chevron"
fi

if grep -F 'Greetd.respond(secret)' "$ROOT/stow/greeter/.config/quickshell/greeter/GreetdAuth.qml" >/dev/null \
    && grep -F 'password.text' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionForm.qml" >/dev/null \
    && grep -F 'IBeamCursor' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionField.qml" >/dev/null \
    && grep -F 'active: true' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionSurface.qml" >/dev/null \
    && grep -F 'interactive: true' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'autoFocus: win.grabKeys' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'WlrKeyboardFocus.Exclusive' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'HyprlandFocusGrab' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'keyGrab.active = true' "$ROOT/stow/greeter/.config/quickshell/greeter/shell.qml" >/dev/null \
    && grep -F 'onPasswordChanged' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionForm.qml" >/dev/null \
    && grep -F 'onUsernameChanged' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionForm.qml" >/dev/null \
    && grep -F 'onLaunchingChanged' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionForm.qml" >/dev/null \
    && grep -F 'tabFocus: root.autoFocus && !String' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionIdentity.qml" >/dev/null \
    && ! grep -F 'session.unavailable' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionForm.qml" >/dev/null; then
    ok "greeter submits the field password and shows the form on every output"
else
    err "GreetdAuth must respond with the pending password; form on every output"
fi

FORM="$ROOT/stow/greeter/.config/quickshell/greeter/SessionForm.qml"
LOCK="$ROOT/stow/shell/.config/quickshell/modern/Modules/Session/SessionSurface.qml"
UNLOCK="$ROOT/stow/shell/.config/quickshell/modern/Modules/Session/SessionUnlockForm.qml"
if grep -F 'Layout.topMargin' "$FORM" >/dev/null \
    && grep -F 'spaceXl' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionIdentity.qml" >/dev/null \
    && grep -F 'Tokens.spacing.xl' "$LOCK" >/dev/null \
    && grep -F 'Layout.topMargin: Tokens.spacing.xl' "$UNLOCK" >/dev/null; then
    ok "login and lock share avatar-to-field and button top spacing"
else
    err "Sign in / Unlock need top spacing; lock must match avatar-to-name gap"
fi

if grep -F 'kiosk.sh' "$LIB" >/dev/null \
    && grep -F '50-modern-greeter.rules' "$LIB" >/dev/null \
    && grep -F 'GREETD_SOCK' "$ROOT/install/system/greetd/kiosk.sh" >/dev/null \
    && grep -F 'GREETD_SOCK' "$ROOT/install/system/greetd/hyprland.lua" >/dev/null \
    && grep -F 'list-users.py' "$LIB" >/dev/null \
    && grep -F 'json.lua' "$LIB" >/dev/null \
    && grep -Fq 'source_profile = false' "$ROOT/install/system/greetd/config.toml" \
    && grep -Fq 'disable_hyprland_guiutils_check' "$ROOT/install/system/greetd/hyprland.lua" \
    && [ ! -f "$ROOT/stow/greeter/.config/quickshell/greeter/SessionHandoff.qml" ] \
    && ! grep -F 'SessionHandoff' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionSurface.qml" >/dev/null \
    && ! grep -F 'property bool slow' "$ROOT/stow/greeter/.config/quickshell/greeter/GreetdAuth.qml" >/dev/null \
    && grep -Fq 'ulimit -c 0' "$ROOT/install/system/greetd/kiosk.sh" \
    && grep -Fq -- '--no-nixgl' "$ROOT/stow/greeter/.config/quickshell/greeter/GreetdAuth.qml" \
    && grep -F 'onLaunched' "$ROOT/stow/greeter/.config/quickshell/greeter/GreetdAuth.qml" >/dev/null \
    && grep -F '/usr/bin/systemctl' "$ROOT/stow/greeter/.config/quickshell/greeter/SessionPower.qml" >/dev/null \
    && grep -F 'hl.dsp.exit()' "$ROOT/stow/greeter/.config/quickshell/greeter/GreetdAuth.qml" >/dev/null \
    && grep -Fq 'hl.dsp.cursor.move' "$ROOT/install/system/greetd/hyprland.lua" \
    && ! grep -F 'movecursor' "$ROOT/install/system/greetd/hyprland.lua" >/dev/null \
    && grep -F 'hl.dsp.exit()' "$ROOT/stow/shell/.config/quickshell/modern/Services/Power.qml" >/dev/null \
    && ! grep -F '"exit"' "$ROOT/stow/shell/.config/quickshell/modern/Services/Power.qml" >/dev/null \
    && ! grep -F 'awww-daemon' "$ROOT/install/system/greetd/hyprland.lua" >/dev/null \
    && grep -Fq 'transition-type none' "$ROOT/stow/hypr/.config/hypr/modules/autostart.lua" \
    && ! grep -F 'wallpaper-show.sh' "$ROOT/stow/hypr/.config/hypr/modules/autostart.lua" >/dev/null; then
    ok "greetd_apply installs the GREETD_SOCK kiosk"
else
    err "greetd_apply must install kiosk.sh, hyprland.lua GREETD_SOCK, list-users.py, and json.lua"
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

# Isolated bash: greetd_apply's `exit 1` must not kill this script, and
# the child must not see a pre-existing greeter account (CI has none;
# this PC does).
dry_out="$(
    bash --noprofile --norc -c '
        set -euo pipefail
        export REPO_ROOT="$1" LOG_FILE="/dev/null" DRY_RUN=1
        PATH="$2"
        # Hide a live greeter so this matches GitHub Actions.
        getent() {
            if [ "${1:-}" = passwd ] && [ "${2:-}" = greeter ]; then
                return 2
            fi
            command getent "$@"
        }
        id() {
            if [ "${1:-}" = greeter ]; then
                return 1
            fi
            command id "$@"
        }
        # shellcheck source=../install/lib/log.sh
        source "$REPO_ROOT/install/lib/log.sh"
        # shellcheck source=../install/lib/ui.sh
        source "$REPO_ROOT/install/lib/ui.sh"
        # shellcheck source=../install/lib/greetd.sh
        source "$REPO_ROOT/install/lib/greetd.sh"
        greetd_apply "$3"
    ' _ "$ROOT" "$PATH" "$(id -un)" 2>&1
)" && dry_rc=0 || dry_rc=$?
if [ "$dry_rc" -eq 0 ] \
    && printf '%s\n' "$dry_out" | grep -F 'would enable greetd.service' >/dev/null; then
    ok "dry-run lists greetd enable"
else
    err "greetd_apply DRY_RUN must list greetd enable (rc=$dry_rc)"
    printf '%s\n' "$dry_out" | tail -n 20 >&2
fi

if (
    unset LANG LC_ALL LC_MESSAGES I18N_LANG
    set -u
    export REPO_ROOT="$ROOT"
    # shellcheck source=../install/lib/i18n.sh
    source "$ROOT/install/lib/i18n.sh"
    [ "$I18N_LANG" = "en" ]
); then
    ok "i18n.sh survives unset LANG"
else
    err "i18n.sh must not abort when LANG is unset (SUPER+Q / reload_ui)"
fi

[ "$FAIL" -eq 0 ]
