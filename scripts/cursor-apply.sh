#!/usr/bin/env bash
# Apply a cursor theme and size to Hyprland, GTK, and the inherited
# XCursor default. Settings writes config.json only; this is the live
# apply path (Services/Hypr.setCursor).
set -euo pipefail

theme="${1:-}"
size="${2:-24}"
if [ -z "$theme" ]; then
    echo "cursor-apply: missing theme" >&2
    exit 2
fi
if ! [[ "$size" =~ ^[0-9]+$ ]]; then
    echo "cursor-apply: size must be a number" >&2
    exit 2
fi

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl setcursor "$theme" "$size" >/dev/null 2>&1 || true
    hyprctl keyword env "XCURSOR_THEME,$theme" >/dev/null 2>&1 || true
    hyprctl keyword env "XCURSOR_SIZE,$size" >/dev/null 2>&1 || true
    hyprctl keyword env "HYPRCURSOR_THEME,$theme" >/dev/null 2>&1 || true
    hyprctl keyword env "HYPRCURSOR_SIZE,$size" >/dev/null 2>&1 || true
fi

dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/default"
mkdir -p "$dir" "$HOME/.icons/default"
idx="[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=${theme}
"
printf '%s\n' "$idx" >"$dir/index.theme"
printf '%s\n' "$idx" >"$HOME/.icons/default/index.theme"

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "$theme" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-size "$size" >/dev/null 2>&1 || true
fi
