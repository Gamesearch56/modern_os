#!/usr/bin/env bash
# Print wallpaper paths, one per line. Used by Services/Wallpaper.qml.
# User library first so a seeded Pictures copy wins over the same
# basename in the shipped ~/.config/modern/wallpapers pack.
# xdg-user-dir PICTURES returns $HOME when user-dirs.dirs is missing, so
# we always also scan $HOME/Pictures/{Wallpaper,Wallpapers}.
set -euo pipefail

pic="$(xdg-user-dir PICTURES 2>/dev/null || true)"
if [ -z "${pic:-}" ] || [ "$pic" = "$HOME" ]; then
    pic="$HOME/Pictures"
fi

dirs=()
for d in \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Pictures/Wallpaper" \
    "$pic/Wallpapers" \
    "$pic/Wallpaper" \
    "$HOME/.config/modern/wallpapers"
do
    if [ -d "$d" ]; then
        already=0
        for e in "${dirs[@]+"${dirs[@]}"}"; do
            if [ "$e" = "$d" ]; then
                already=1
                break
            fi
        done
        if [ "$already" -eq 0 ]; then
            dirs+=("$d")
        fi
    fi
done

if [ "${#dirs[@]}" -eq 0 ]; then
    exit 0
fi

# Newest-added first. Import/fetch write without preserving source
# mtime, so modification time is "when it landed in the library".
{
    for d in "${dirs[@]}"; do
        find -L "$d" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            -printf '%T@\t%p\0'
    done
} | {
    declare -A seen=()
    declare -A seen_base=()
    while IFS= read -r -d '' rec; do
        ts="${rec%%$'\t'*}"
        f="${rec#*$'\t'}"
        real="$(realpath "$f" 2>/dev/null || true)"
        [ -n "$real" ] || continue
        base="${real##*/}"
        base="${base,,}"
        if [ -n "${seen[$real]+x}" ] || [ -n "${seen_base[$base]+x}" ]; then
            continue
        fi
        seen[$real]=1
        seen_base[$base]=1
        printf '%s\t%s\n' "$ts" "$real"
    done
} | sort -nr -k1,1 | cut -f2-
