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
GAME_MATCH="$ROOT/stow/hypr/.config/hypr/modules/game_match.lua"
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

qs_fix="$(mktemp)"
printf '%s\n' '[{"class":"org.quickshell","title":"modern.settings","workspace":{"id":2},"address":"0xsettings"},{"class":"org.quickshell","title":"modern.files","workspace":{"id":2},"address":"0xaway"},{"class":"org.quickshell","title":"modern.files","workspace":{"id":4},"address":"0xhere"}]' >"$qs_fix"
got="$(MODERN_RAISE_DRY=1 MODERN_RAISE_WORKSPACE=4 MODERN_RAISE_CLIENTS="$qs_fix" "$RAISE" modern.files || true)"
away="$(MODERN_RAISE_DRY=1 MODERN_RAISE_WORKSPACE=9 MODERN_RAISE_CLIENTS="$qs_fix" "$RAISE" modern.files || true)"
rm -f "$qs_fix"
if [[ "$got" == "0xhere" && "$away" == "0xaway" ]]; then
    ok "file manager raise uses the Quickshell title and prefers this workspace"
else
    err "session-raise modern.files should prefer this workspace, got ${got:-empty} / ${away:-empty}"
fi

files_mod="$ROOT/stow/shell/.config/quickshell/modern/Modules/Files/Module.qml"
files_win="$ROOT/stow/hypr/.config/hypr/modules/windows.lua"
files_tok="$ROOT/stow/shell/.config/quickshell/modern/Commons/Tokens.qml"
if grep -Fq 'onVisibleChanged: if (!visible) Files.hide()' "$files_mod" \
    && grep -Fq 'size = { 1172, 704 }' "$files_win" \
    && grep -Fq 'win.filesCell * 5' "$files_tok" \
    && grep -Fq 'root.spacing.md * 4' "$files_tok"; then
    ok "file manager clears open on Super+Q and keeps Hyprland size on the token width"
else
    err "modern.files must hide on visible loss and match Tokens.window.filesWidth"
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

mail_home="$(mktemp -d)"
printf '%s\n' '[{"class":"vivaldi-mail.proton.me__-Default","address":"0xmail"},{"class":"TradeSkillMaster","address":"0xtsm"}]' >"$mail_home/clients.json"
got_mail="$(MODERN_RAISE_DRY=1 MODERN_RAISE_CLIENTS="$mail_home/clients.json" "$RAISE" proton-mail || true)"
got_tsm="$(MODERN_RAISE_DRY=1 MODERN_RAISE_CLIENTS="$mail_home/clients.json" "$RAISE" tradeskillmaster || true)"
rm -rf "$mail_home"
if [[ "$got_mail" == "0xmail" && "$got_tsm" == "0xtsm" ]]; then
    ok "TradeSkillMaster raise does not steal the Proton Mail window"
else
    err "tradeskillmaster must not raise vivaldi mail (mail=${got_mail:-empty} tsm=${got_tsm:-empty})"
fi
if command -v lua >/dev/null 2>&1; then
    if lua -e '
        package.path = "'"$ROOT"'/stow/hypr/.config/hypr/?.lua;" .. package.path
        local m = require("modules.session_match")
        assert(m.field_matches("vivaldi-mail.proton.me__-Default", "proton-mail.desktop"))
        assert(not m.field_matches("vivaldi-mail.proton.me__-Default", "tradeskillmaster.desktop"))
        assert(m.field_matches("TradeSkillMaster", "tradeskillmaster.desktop"))
    '; then
        ok "session_match keeps TradeSkillMaster off the Proton Mail rule"
    else
        err "session_match still treats tradeskillmaster as proton mail"
    fi
fi

if grep -Fq 'hl.dsp.exec_cmd' "$LAUNCH" \
    && ! grep -E '^[[:space:]]*exec hyprctl dispatch exec' "$LAUNCH" >/dev/null; then
    ok "--background uses Lua exec_cmd"
else
    err "modern-launch --background must not call hyprctl dispatch exec"
fi

if grep -Fq 'move_to_background' "$SESSION" \
    && grep -Fq 'pin_background' "$SESSION" \
    && grep -Fq '__modern_as_spawn' "$SESSION" \
    && grep -Fq 'session_direct_apps' "$SESSION" \
    && grep -Fq 'vivaldi --app=' "$ROOT/stow/hypr/.config/hypr/modules/session_direct_apps.lua" \
    && ! grep -Fq 'user-data-dir' "$ROOT/stow/hypr/.config/hypr/modules/session_direct_apps.lua" \
    && grep -Fq '{ timeout = 250,' "$SESSION" \
    && grep -Fq 'delay = delay + 200' "$SESSION" \
    && ! grep -Fq '{ timeout = 2000,' "$SESSION" \
    && ! grep -Fq 'delay = delay + 1500' "$SESSION" \
    && ! grep -Fq 'special:background silent' "$SESSION" \
    && grep -Fq 'special:background silent' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'modern-bg-' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq '"__-.*$"' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && ! grep -Fq '"__%-"' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'profile-directory' "$ROOT/scripts/vivaldi" \
    && grep -Fq 'password-store=basic' "$ROOT/scripts/vivaldi" \
    && grep -Fq '"--password-store=basic"' "$ROOT/stow/xdg/.config/spotify-launcher.conf" \
    && grep -Fq 'DbusSecretPortal' "$ROOT/scripts/vivaldi" \
    && grep -Fq 'keystore_canary' "$ROOT/scripts/vivaldi" \
    && ! grep -Fq 'gnome-keyring-hyprland' "$ROOT/stow/xdg/.config/xdg-desktop-portal/hyprland-portals.conf" \
    && ! grep -Fq 'gnome-keyring-hyprland' "$ROOT/install/system/portals/hyprland-portals.conf" \
    && [ ! -e "$ROOT/stow/xdg/.local/share/xdg-desktop-portal/portals/gnome-keyring-hyprland.portal" ] \
    && grep -Fq 'initialClass' "$ROOT/stow/hypr/.config/hypr/modules/session_match.lua" \
    && grep -Fq 'window = w' "$SESSION" \
    && grep -Fq 'covers workspace 1' "$ROOT/stow/hypr/.config/hypr/modules/workspaces.lua" \
    && grep -Fq 'warp_on_toggle_special' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'background-move.sh' "$HIDE" \
    && grep -Fq 'specialWorkspace.name' "$ROOT/scripts/background-move.sh" \
    && grep -Fq 'background-move.sh' "$HYPR_WIN" \
    && grep -Fq 'background-raise.sh' "$HYPR_WIN" \
    && grep -Fq 'background-raise.sh' "$RAISE" \
    && ! grep -Fq 'workspace.move' "$RAISE" \
    && grep -Fq 'window_fade_out' "$ROOT/scripts/background-move.sh" \
    && grep -Fq 'window_fade_prepare_in' "$ROOT/scripts/background-raise.sh" \
    && grep -Fq 'leaf = "fadeSwitch"' "$ROOT/stow/hypr/.config/hypr/modules/animations.lua" \
    && grep -Fq 'emphasizedAccelerate' "$ROOT/scripts/lib/window-fade.sh" \
    && grep -Fq 'durationMediumMs' "$ROOT/scripts/lib/window-fade.sh" \
    && ! grep -Fq 'session-park' "$SESSION" \
    && ! grep -Fq 'move_bg' "$SESSION" \
    && ! grep -Fq 'arm_park' "$SESSION" \
    && ! grep -Fq 'schedule_sweeps' "$SESSION"; then
    ok "login opens Vivaldi apps on the main profile and pins special:background"
else
    err "session_apps must launch Vivaldi --app on the main profile and pin special:background"
fi

WA_DESK="$ROOT/stow/xdg/.local/share/applications/whatsapp.desktop"
MAIL_DESK="$ROOT/stow/xdg/.local/share/applications/proton-mail.desktop"
CAL_DESK="$ROOT/stow/xdg/.local/share/applications/proton-calendar.desktop"
if grep -Fq -- '--app=https://web.whatsapp.com' "$WA_DESK" \
    && grep -Fq -- '--app=https://mail.proton.me' "$MAIL_DESK" \
    && grep -Fq -- '--app=https://calendar.proton.me' "$CAL_DESK" \
    && ! grep -Fq 'user-data-dir' "$WA_DESK" \
    && ! grep -Fq 'user-data-dir' "$MAIL_DESK" \
    && ! grep -Fq 'user-data-dir' "$CAL_DESK"; then
    ok "desktop entries open Vivaldi apps on the main profile"
else
    err "whatsapp/proton desktop Exec must use --app on the main Vivaldi profile"
fi

if [[ -x "$RAISE" ]] \
    && [[ -x "$HIDE" ]] \
    && grep -Fq 'bind the needle' "$RAISE" \
    && grep -Fq 'raiseDesktopOrLaunch' "$HYPR_WIN" \
    && grep -Fq 'raiseDesktopOrLaunch' "$LAUNCHER" \
    && grep -Fq 'windowParked' "$HYPR_WIN" \
    && grep -Fq 'windowParked' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'special:' "$ROOT/stow/shell/.config/quickshell/modern/Services/taskbarEntries.js" \
    && grep -Fq 'isAutostartDesktop' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'isAutostartDesktop' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprAutostart.qml" \
    && grep -Fq 'session-raise.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq '_armParkedOpen' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'hl.dsp.window.float' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'hl.dsp.window.fullscreen' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq 'session-hide.sh' "$MODERN" \
    && grep -Fq 'x-scheme-handler/http' "$LAUNCH" \
    && grep -Fq 'x-scheme-handler/mailto' "$LAUNCH" \
    && grep -Fq 'execString' "$ROOT/stow/shell/.config/quickshell/modern/Services/Notifications.qml" \
    && grep -Fq -- '--app=https?' "$ROOT/stow/shell/.config/quickshell/modern/Services/Notifications.qml"; then
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

OV_STAGE="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/Stage.qml"
OV_CARD="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/WindowCard.qml"
OV_MOD="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/Module.qml"
OV_INPUT="$ROOT/stow/hypr/.config/hypr/modules/input.lua"
if grep -Fq 'modern.overview' "$HYPR_WIN" \
    && grep -Fq 'modern.settings' "$HYPR_WIN" \
    && grep -Fq '_overlayTitle' "$HYPR_WIN" \
    && grep -Fq 'ScreencopyView' "$OV_CARD" \
    && grep -Fq 'displayNameForHint' "$OV_CARD" \
    && grep -Fq 'sequence: "Tab"' "$OV_MOD" \
    && grep -Fq 'PanelWindow' "$OV_MOD" \
    && grep -Fq 'WheelHandler' "$OV_STAGE" \
    && grep -Fq 'modernoverview,' "$OV_INPUT" \
    && ! grep -Fq 'overview open' "$OV_INPUT"; then
    ok "overview follows the swipe and shows live tiles"
else
    err "overview must follow the swipe, filter overlays, and keep Tab"
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

if grep -Fq 'explorer.exe' "$GAME_MATCH" \
    && grep -Fq 'steam_app_%d+' "$GAME_MATCH" \
    && grep -Fq 'proton-desktop-silent' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && ! grep -Fq 'keep_windowed' "$GAMES" \
    && grep -Fq 'wine-shell-silent' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'battlenet-no-client-fullscreen' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'suppress_event = "fullscreen maximize"' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua"; then
    ok "Battle.net ignores its own fullscreen request; SUPER+F still toggles"
else
    err "launcher must suppress client fullscreen without trapping SUPER+F"
fi

if grep -Fq 'nautilus' "$GAME_MATCH" \
    && grep -Fq 'MAX_ID' "$GAME_MATCH" \
    && grep -Fq 'window.fullscreen' "$GAMES" \
    && ! grep -Fq 're2_alt' "$GAME_MATCH" "$GAMES" \
    && grep -Fq 'suppress-client-maximize' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'steamwebhelper' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua"; then
    ok "file manager titles stay out of the game matcher"
else
    err "games.lua must ignore file managers and not Lua-match window titles"
fi

if ! grep -Fq 'window.open_early' "$GAMES" \
    && ! grep -Eq 'hl\.on\("window\.[a-z_]+", consider\)' "$GAMES" \
    && grep -Fq 'hl.on("window.open", later)' "$GAMES" \
    && grep -Fq 'has_fullscreen' "$GAMES"; then
    ok "game auto-fullscreen runs after the map and leaves a fullscreen game alone"
else
    err "games.lua must not dispatch fullscreen inside mapWindow (crashes Hyprland 0.57)"
fi

if grep -Fq 'virtual_gpu' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq '0x1af4' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'hypervisor' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq '0x10de' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'MODERN_SOFTWARE_GPU' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'QSG_RHI_BACKEND' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'enabled = not soft' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'cm_enabled = not soft' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'use_fp16 = soft and 0 or 2' "$ROOT/stow/hypr/.config/hypr/modules/general.lua" \
    && grep -Fq 'imv-no-blur' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" \
    && grep -Fq 'softwareGpu' \
        "$ROOT/stow/shell/.config/quickshell/modern/Commons/Chrome.qml" \
    && grep -Fq 'Chrome.softwareGpu ? Colors.color.surface' \
        "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/BarWindow.qml" \
    && grep -Fq 'anchors.right: !root._soft' \
        "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/BarLayerPopup.qml"; then
    ok "virtual GPUs skip the black translucent path; desktop GPUs stay frosted"
else
    err "virtual GPU must disable blur, fp16, and color management without changing a real GPU"
fi

POPUPS="$ROOT/stow/hypr/.config/hypr/modules/browser_popups.lua"
if grep -Fq 'require("modules.browser_popups")' \
        "$ROOT/stow/hypr/.config/hypr/hyprland.lua" \
    && grep -Fq 'action = on and "set" or "unset"' "$POPUPS" \
    && grep -Fq 'origin_stamp' "$POPUPS" \
    && grep -Fq 'app_class' "$POPUPS" \
    && grep -Fq 'document_title' "$POPUPS" \
    && grep -Fq 'SETTLE_MS' "$POPUPS" \
    && grep -Fq 'drop_vivaldi_notice' "$POPUPS" \
    && grep -Fq 'hl.get_windows' "$POPUPS" \
    && ! grep -Fq 'hyprctl clients' "$POPUPS" \
    && grep -Fq 'org.freedesktop.Notifications' \
        "$ROOT/stow/hypr/.config/hypr/modules/session_apps.lua" \
    && grep -Fq 'another_open' \
        "$ROOT/stow/hypr/.config/hypr/modules/session_apps.lua"; then
    ok "browser notification toplevels close once the notification service is up"
else
    err "anonymous browser notification windows must close into a system notification"
fi

activate="$(awk '/function activate\(item\)/,/^    }$/' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Notifications.qml")"
invoke_at="$(grep -n 'invokeDefault(live)' <<<"$activate" | head -n1 | cut -d: -f1)"
raise_at="$(grep -n 'Hypr.raiseApp' <<<"$activate" | head -n1 | cut -d: -f1)"
if grep -Fq 'Apps.openInFileManager(file)' <<<"$activate" \
    && grep -Fq '"files", "reveal"' "$ROOT/stow/shell/.config/quickshell/modern/Services/fileManager.js" \
    && grep -Fq 'org.freedesktop.FileManager1' "$ROOT/scripts/file-manager-bus.py" \
    && grep -Fq 'function reveal' "$ROOT/stow/shell/.config/quickshell/modern/Services/Files.qml" \
    && grep -Fq 'session-raise.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml" \
    && grep -Fq '!(wsId > 0)' "$HYPR_WIN" \
    && [ -n "$invoke_at" ] && [ -n "$raise_at" ] && [ "$invoke_at" -lt "$raise_at" ]; then
    ok "a screenshot toast reveals its file; an app notification runs its action before raising"
else
    err "notification click must reveal shell toast files and invoke app actions even when the app is open"
fi

if grep -Fq 'Hypr.raiseDesktop' "$ROOT/stow/shell/.config/quickshell/modern/Services/Tray.qml" \
    && grep -Fq 'Tray.activate' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/tray/Widget.qml"; then
    ok "a tray icon can raise its application"
else
    err "tray activation must raise the owning application"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-modern-launch: ok\n'
