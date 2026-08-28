#!/usr/bin/env bash
# Print wallpaper paths, one per line. Used by Services/Wallpaper.qml.
# User library first so full-resolution imports win over the shipped
# fallback (Cursor chat attachments in the stow pack are 1024px).
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

# Preserve directory order (library, then shipped). sort -u would put
# ~/.config/modern/wallpapers first and make the 1024px copies the
# tiles you actually click.
declare -A seen=()
for d in "${dirs[@]}"; do
    while IFS= read -r -d '' f; do
        real="$(realpath "$f")"
        if [ -n "${seen[$real]+x}" ]; then
            continue
        fi
        seen[$real]=1
        printf '%s\n' "$real"
    done < <(find -L "$d" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        -print0 | sort -z)
done
