#!/usr/bin/env bash
# Print wallpaper paths, one per line. Used by Services/Wallpaper.qml.
# User library (XDG PICTURES/Wallpapers) first so it wins over the same
# basename in the shipped ~/.config/modern/wallpapers pack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

dirs=()
while IFS= read -r d; do
    [ -d "$d" ] || continue
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
done < <(xdg_wallpaper_library_dirs)

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
