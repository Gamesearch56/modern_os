#!/usr/bin/env bash
# Steam desktop shortcuts live on the desktop and their icons are pngs
# written after the shell started. The scanner has to return the png path.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$ROOT/scripts/desktop-shortcuts.py"
FAIL=0
err() { printf 'test-desktop-shortcuts: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-desktop-shortcuts: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/desk" "$TMP/icons/hicolor/256x256/apps" "$TMP/icons/hicolor/16x16/apps" \
    "$TMP/icons/hicolor/48x48/apps" "$TMP/icons/hicolor/128x128/apps"
printf 'x' > "$TMP/icons/hicolor/256x256/apps/steam_icon_1636440.png"
printf 'x' > "$TMP/icons/hicolor/16x16/apps/steam_icon_1636440.png"
printf 'x' > "$TMP/icons/hicolor/48x48/apps/steam_icon_99.png"
cat > "$TMP/desk/SILENT HILL Townfall.desktop" << 'EOF'
[Desktop Entry]
Name=SILENT HILL: Townfall
Exec=steam steam://rungameid/1636440
Icon=steam_icon_1636440
Type=Application
EOF
cat > "$TMP/desk/Hidden Game.desktop" << 'EOF'
[Desktop Entry]
Name=Hidden Game
Exec=steam steam://rungameid/1
Icon=steam_icon_1
NoDisplay=true
Type=Application
EOF
cat > "$TMP/desk/Link.desktop" << 'EOF'
[Desktop Entry]
Name=Not An App
Exec=true
Type=Link
EOF
printf 'x' > "$TMP/icons/hicolor/128x128/apps/steam_icon_5.png"
cat > "$TMP/desk/Empty Icon.desktop" << 'EOF'
[Desktop Entry]
Name=Empty Icon Game
Exec=steam steam://rungameid/5 %u
Icon=
Type=Application
EOF

out="$(MODERN_DESKTOP_DIR="$TMP/desk" MODERN_ICON_ROOTS="$TMP/icons" python3 "$SCAN")"

name="$(printf '%s' "$out" | jq -r '.shortcuts[] | select(.id == "SILENT HILL Townfall") | .name')"
icon="$(printf '%s' "$out" | jq -r '.icons["steam_icon_1636440"]')"
argv0="$(printf '%s' "$out" | jq -r '.shortcuts[] | select(.id == "SILENT HILL Townfall") | .argv[0]')"
argv1="$(printf '%s' "$out" | jq -r '.shortcuts[] | select(.id == "SILENT HILL Townfall") | .argv[1]')"
hidden="$(printf '%s' "$out" | jq -r '.shortcuts[] | select(.name == "Hidden Game") | .id')"
link="$(printf '%s' "$out" | jq -r '.shortcuts[] | select(.name == "Not An App") | .id')"
empty_icon="$(printf '%s' "$out" | jq -r '.icons["steam_icon_5"]')"
empty_argv="$(printf '%s' "$out" | jq -r '.shortcuts[] | select(.id == "Empty Icon") | .argv | length')"
indexed="$(printf '%s' "$out" | jq -r '.icons["steam_icon_99"]')"

if [[ "$name" == "SILENT HILL: Townfall" && "$argv0" == "steam" && "$argv1" == "steam://rungameid/1636440" ]]; then
    ok "shortcut name and launch command"
else
    err "shortcut parse: name=$name argv=$argv0 $argv1"
fi
if [[ "$icon" == "$TMP/icons/hicolor/256x256/apps/steam_icon_1636440.png" ]]; then
    ok "largest steam png"
else
    err "expected the 256px png, got $icon"
fi
if [[ -z "$hidden" && -z "$link" ]]; then
    ok "hidden and non-application files stay out"
else
    err "hidden=$hidden link=$link"
fi
if [[ "$empty_icon" == "$TMP/icons/hicolor/128x128/apps/steam_icon_5.png" && "$empty_argv" == "2" ]]; then
    ok "game id fills a blank icon and field codes are dropped"
else
    err "empty icon=$empty_icon argvlen=$empty_argv"
fi
if [[ "$indexed" == "$TMP/icons/hicolor/48x48/apps/steam_icon_99.png" ]]; then
    ok "steam pngs are indexed even without a desktop file"
else
    err "indexed=$indexed"
fi

if grep -Fq 'DesktopShortcuts.iconFor' "$ROOT/stow/shell/.config/quickshell/modern/Services/AppsIcons.qml" \
    && grep -Fq 'DesktopShortcuts.rows' "$ROOT/stow/shell/.config/quickshell/modern/Services/Launcher.qml"; then
    ok "the app list asks for the file path"
else
    err "launcher and icon lookup must use DesktopShortcuts"
fi

exit "$FAIL"
