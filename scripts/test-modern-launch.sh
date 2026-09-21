#!/usr/bin/env bash
# Autostart must spawn via Lua exec_cmd. Hyprland 0.56 rejects
# `hyprctl dispatch exec`, which left mail/chat never launched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-modern-launch: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-modern-launch: ok %s\n' "$*"; }

LAUNCH="$ROOT/scripts/modern-launch"
AUTO="$ROOT/stow/hypr/.config/hypr/modules/autostart.lua"
SESSION="$ROOT/stow/hypr/.config/hypr/modules/session_apps.lua"
MATCH="$ROOT/stow/hypr/.config/hypr/modules/session_match.lua"
LAYOUT="$ROOT/stow/hypr/.config/hypr/modules/workspaces_layout.lua"
GAMES="$ROOT/stow/hypr/.config/hypr/modules/games.lua"
HYPR_AS="$ROOT/stow/shell/.config/quickshell/modern/Services/HyprAutostart.qml"
HYPR_WIN="$ROOT/stow/shell/.config/quickshell/modern/Services/HyprWindows.qml"
AUTOSTART_UI="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/applications/Autostart.qml"
PROFILE="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/displays/ProfileForm.qml"
DEFAULTS="$ROOT/stow/modern/.config/modern/config.default.json"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"

if grep -Fq 'session_apps' "$AUTO" \
    && grep -Fq 'on_start' "$AUTO"; then
    ok "autostart.lua starts session_apps on hyprland.start"
else
    err "autostart.lua must require session_apps.on_start"
fi

if [[ ! -f "$MATCH" ]]; then
    err "session_match.lua missing from stow (restow hypr after adding it)"
elif grep -Fq 'pcall(require, "modules.session_match")' "$SESSION" \
    || grep -Fq 'require("modules.session_match")' "$SESSION"; then
    ok "session_apps loads session_match (stow must link the new module)"
else
    err "session_apps must require session_match"
fi

if grep -Fq 'hl.dsp.exec_cmd' "$LAUNCH" \
    && ! grep -E '^[[:space:]]*exec hyprctl dispatch exec' "$LAUNCH" >/dev/null; then
    ok "--background uses Lua exec_cmd"
else
    err "modern-launch --background must not call hyprctl dispatch exec"
fi

if [[ -x "$ROOT/scripts/session-park.sh" ]] \
    && grep -Fq 'session-park.sh' "$SESSION" \
    && grep -Fq 'special:background silent' "$SESSION" \
    && grep -Fq 'follow = false' "$SESSION" \
    && grep -Fq 'vivaldi-stable --app=' "$SESSION" \
    && grep -Fq 'window.class' "$SESSION"; then
    ok "session-park + direct --app= + follow=false special:background park"
else
    err "session_apps must park via follow=false move and session-park.sh"
fi

if grep -Fq 'url_tokens' "$MATCH" \
    && grep -Fq 'mailproton' "$MATCH" \
    && grep -Fq '_urlTokens' "$HYPR_AS" \
    && ! grep -Fq 'classn.indexOf("vivaldi") !== 0' "$HYPR_AS"; then
    ok "shared URL match does not require vivaldi class prefix"
else
    err "session_match / HyprAutostart must match URL tokens without vivaldi prefix"
fi

if grep -Fq 'window.close' "$SESSION" \
    && grep -Fq 'hideAutostart' "$HYPR_WIN" \
    && grep -Fq 'forceKillWindow' "$HYPR_WIN" \
    && grep -Fq 'forceKillAutostart' "$HYPR_WIN" \
    && grep -Fq 'forceKillAutostart' "$AUTOSTART_UI" \
    && grep -Fq 'closeFocused' "$ROOT/scripts/modern"; then
    ok "close parks; Settings Autostart close force-kills"
else
    err "close must hide; Autostart.qml must forceKillAutostart"
fi

if grep -Fq 'primaryDescription' "$DEFAULTS" \
    && grep -Fq 'function M.primary' "$LAYOUT" \
    && grep -Fq 'first_connected' "$LAYOUT" \
    && grep -Fq 'settings.fields.primaryMonitor' "$PROFILE" \
    && grep -Fq 'primaryMonitor' "$EN" \
    && grep -Fq 'primaryMonitor' "$DE" \
    && grep -Fq 'focus_primary' \
    "$ROOT/stow/hypr/.config/hypr/modules/workspaces.lua" \
    && ! grep -Fq 'snap_primary' "$GAMES"; then
    ok "primary display config/UI/boot focus; games no longer snap to primary"
else
    err "primaryDescription + ProfileForm + no games snap_primary required"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-modern-launch: ok\n'
