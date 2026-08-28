#!/usr/bin/env bash
# Print wallpaper paths, one per line. Used by Services/Wallpaper.qml.
# xdg-user-dir PICTURES returns $HOME when user-dirs.dirs is missing, so
# we always also scan $HOME/Pictures/{Wallpaper,Wallpapers}.
set -euo pipefail

pic="$(xdg-user-dir PICTURES 2>/dev/null || true)"
if [ -z "${pic:-}" ] || [ "$pic" = "$HOME" ]; then
    pic="$HOME/Pictures"
fi

dirs=()
for d in \
    "$HOME/.config/modern/wallpapers" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Pictures/Wallpaper" \
    "$pic/Wallpapers" \
    "$pic/Wallpaper"
do
    if [ -d "$d" ]; then
        dirs+=("$d")
    fi
done

if [ "${#dirs[@]}" -eq 0 ]; then
    exit 0
fi

find -L "${dirs[@]}" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort -u
