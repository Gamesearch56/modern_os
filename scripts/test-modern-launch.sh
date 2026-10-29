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
RAISE="$ROOT/scripts/session-raise.sh"
HIDE="$ROOT/scripts/session-hide.sh"
LAUNCHER="$ROOT/stow/shell/.config/quickshell/modern/Services/Launcher.qml"
MODERN="$ROOT/scripts/modern"

if grep -Fq 'session_apps' "$AUTO" \
    && grep -Fq 'on_start' "$AUTO"; then
    ok "autostart.lua starts session_apps on hyprland.start"
else
    err "autostart.lua must require session_apps.on_start"
fi

if grep -Fq 'current-wallpaper' "$AUTO" \
    && grep -Fq 'session/wallpaper.jpg' "$AUTO" \
    && grep -Fq 'head -n 1' "$AUTO" \
    && grep -Fq 'pgrep -x awww-daemon' "$AUTO" \
    && grep -Fq 'transition-type none' "$AUTO"; then
    state_line="$(grep -n 'current-wallpaper' "$AUTO" | head -1 | cut -d: -f1)"
    shared_line="$(grep -n 'session/wallpaper.jpg' "$AUTO" | head -1 | cut -d: -f1)"
    if [ -n "$state_line" ] && [ -n "$shared_line" ] && [ "$state_line" -le "$shared_line" ]; then
        ok "login wallpaper prefers the session account over the greeter snapshot"
    else
        err "autostart must read current-wallpaper before session/wallpaper.jpg"
    fi
else
    err "autostart must restore current-wallpaper, then default, then the greeter JPEG"
fi

if [[ ! -f "$MATCH" ]]; then
    err "session_match.lua missing from stow (restow hypr after adding it)"
elif grep -Fq 'pcall(require, "modules.session_match")' "$SESSION" \
    || grep -Fq 'require("modules.session_match")' "$SESSION"; then
    ok "session_apps loads session_match (stow must link the new module)"
else
    err "session_apps must require session_match"
fi

if grep -Fq -- '--on-active' "$ROOT/stow/hypr/.config/hypr/modules/keybinds.lua" \
    && grep -Fq -- '--on-active' "$LAUNCH" \
    && grep -Fq 'session-raise.sh' "$LAUNCH"; then
    ok "Super+E brings an existing file manager to this monitor"
else
    err "fileManager must launch with modern-launch --on-active"
fi

raise_fix="$(mktemp)"
printf '%s\n' '[{"class":"org.gnome.NautilusPreviewer","address":"0xpreview"},{"class":"org.gnome.Nautilus","address":"0xfiles"}]' >"$raise_fix"
got="$(MODERN_RAISE_DRY=1 MODERN_RAISE_CLIENTS="$raise_fix" "$RAISE" org.gnome.Nautilus || true)"
rm -f "$raise_fix"
if [[ "$got" == "0xfiles" ]]; then
    ok "file manager raise matches Nautilus, not the previewer"
else
    err "session-raise org.gnome.Nautilus should be 0xfiles, got ${got:-empty}"
fi

if grep -Fq -- '--on-active spotify-launcher' "$ROOT/stow/hypr/.config/hypr/modules/keybinds.lua"; then
    ok "Super+R brings an existing Spotify window to this monitor"
else
    err "spotify must launch with modern-launch --on-active spotify-launcher"
fi

spot_home="$(mktemp -d)"
mkdir -p "$spot_home/applications"
printf '%s\n' '[Desktop Entry]' 'StartupWMClass=spotify' >"$spot_home/applications/spotify-launcher.desktop"
printf '%s\n' '[{"class":"Spotify","address":"0xmusic"}]' >"$spot_home/clients.json"
got="$(XDG_DATA_HOME="$spot_home" XDG_DATA_DIRS="$spot_home" MODERN_RAISE_DRY=1 MODERN_RAISE_CLIENTS="$spot_home/clients.json" "$RAISE" spotify-launcher || true)"
rm -rf "$spot_home"
if [[ "$got" == "0xmusic" ]]; then
    ok "spotify-launcher raise matches StartupWMClass spotify"
else
    err "session-raise spotify-launcher should be 0xmusic, got ${got:-empty}"
fi

if grep -Fq 'hl.dsp.exec_cmd' "$LAUNCH" \
    && ! grep -E '^[[:space:]]*exec hyprctl dispatch exec' "$LAUNCH" >/dev/null; then
    ok "--background uses Lua exec_cmd"
else
    err "modern-launch --background must not call hyprctl dispatch exec"
fi

if grep -Fq 'special:background silent' "$SESSION" \
    && grep -Fq 'pin_background' "$SESSION" \
    && grep -Fq '__modern_as_spawn' "$SESSION" \
    && grep -Fq 'session_direct_apps' "$SESSION" \
    && grep -Fq 'vivaldi-apps' "$ROOT/stow/hypr/.config/hypr/modules/session_direct_apps.lua" \
    && grep -Fq 'user-data-dir' "$ROOT/stow/hypr/.config/hypr/modules/session_direct_apps.lua" \
    && grep -Fq '{ timeout = 250,' "$SESSION" \
    && grep -Fq 'delay = delay + 200' "$SESSION" \
    && ! grep -Fq '{ timeout = 2000,' "$SESSION" \
    && ! grep -Fq 'delay = delay + 1500' "$SESSION" \
    && grep -Fq 'no_initial_focus' "$SESSION" \
    && ! grep -Fq 'session-park' "$SESSION" \
    && ! grep -Fq 'move_bg' "$SESSION" \
    && ! grep -Fq 'arm_park' "$SESSION" \
    && ! grep -Fq 'schedule_sweeps' "$SESSION"; then
    ok "login uses per-app Vivaldi profiles + silent special spawn"
else
    err "session_apps must use vivaldi-apps user-data-dir and pin special:background"
fi

WA_DESK="$ROOT/stow/xdg/.local/share/applications/whatsapp.desktop"
MAIL_DESK="$ROOT/stow/xdg/.local/share/applications/proton-mail.desktop"
CAL_DESK="$ROOT/stow/xdg/.local/share/applications/proton-calendar.desktop"
if grep -Fq 'vivaldi-apps/whatsapp' "$WA_DESK" \
    && grep -Fq 'vivaldi-apps/proton-mail' "$MAIL_DESK" \
    && grep -Fq 'vivaldi-apps/proton-calendar' "$CAL_DESK"; then
    ok "desktop entries use separate Vivaldi user-data-dir profiles"
else
    err "whatsapp/proton desktop Exec must set --user-data-dir under vivaldi-apps"
fi

if [[ -x "$RAISE" ]] \
    && [[ -x "$HIDE" ]] \
    && grep -Fq 'bind the needle' "$RAISE" \
    && grep -Fq 'raiseDesktopOrLaunch' "$HYPR_WIN" \
    && grep -Fq 'raiseDesktopOrLaunch' "$LAUNCHER" \
    && grep -Fq 'isAutostartDesktop' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'isAutostartDesktop' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprAutostart.qml" \
    && grep -Fq 'session-raise.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'hl.dsp.window.float' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'hl.dsp.window.fullscreen' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'session-hide.sh' "$MODERN"; then
    ok "launcher raises via session-raise; Super+Q parks via session-hide"
else
    err "raiseDesktopOrLaunch + session-raise/hide required"
fi

if grep -Fq 'url_tokens' "$MATCH" \
    && grep -Fq 'mailproton' "$MATCH" \
    && grep -Fq '_urlTokens' "$HYPR_AS" \
    && ! grep -Fq 'needle.indexOf(fieldn)' "$HYPR_AS"; then
    ok "shared URL match does not reverse-match short field tokens"
else
    err "session_match / HyprAutostart must not reverse-match field into needle"
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

OV_GRID="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/WindowGrid.qml"
OV_TILE="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/Tile.qml"
OV_MOD="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/Module.qml"
if grep -Fq 'modern.overview' "$HYPR_WIN" \
    && grep -Fq 'modern.settings' "$HYPR_WIN" \
    && grep -Fq '_overlayTitle' "$HYPR_WIN" \
    && grep -Fq 'GridLayout' "$OV_GRID" \
    && ! grep -Fq 'PathView' "$OV_GRID" \
    && grep -Fq 'ScreencopyView' "$OV_TILE" \
    && grep -Fq 'displayNameForHint' "$OV_TILE" \
    && grep -Fq 'sequence: "Tab"' "$OV_MOD"; then
    ok "overview grid shows every window with live tiles"
else
    err "overview must filter overlays, grid all windows, Tab cycle"
fi

if grep -Fq 'primaryDescription' "$DEFAULTS" \
    && grep -Fq 'function M.primary' "$LAYOUT" \
    && grep -Fq 'first_connected' "$LAYOUT" \
    && grep -Fq 'settings.fields.primaryMonitor' "$PROFILE" \
    && grep -Fq 'primaryMonitor' "$EN" \
    && grep -Fq 'primaryMonitor' "$DE" \
    && grep -Fq 'focus_primary' \
    "$ROOT/stow/hypr/.config/hypr/modules/workspaces.lua" \
    && grep -Fq 'hl.dsp.cursor.move' \
    "$ROOT/stow/hypr/.config/hypr/modules/workspaces.lua" \
    && ! grep -Fq 'movetoworkspace' \
    "$ROOT/stow/hypr/.config/hypr/modules/workspaces.lua" \
    && ! grep -Fq 'snap_primary' "$GAMES"; then
    ok "primary display config/UI/boot focus; games no longer snap to primary"
else
    err "primaryDescription + ProfileForm + no games snap_primary required"
fi

if grep -Fq 'virtual_gpu' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'virtio' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'MODERN_SOFTWARE_GPU' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'enabled = not soft' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'imv-no-blur' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'MODERN_SOFTWARE_GPU' \
        "$ROOT/stow/shell/.config/quickshell/modern/Modules/Screenshot/Hud.qml"; then
    ok "virtual GPUs skip acrylic blur so the bar, images, and capture stay visible"
else
    err "virtual GPU must disable blur and keep imv and capture from going black"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-modern-launch: ok\n'
