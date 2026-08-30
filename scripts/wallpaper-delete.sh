#!/usr/bin/env bash
# Remove a file from the user wallpaper library. Refuses shipped
# copies under ~/.config/modern/wallpapers and the currently applied
# wallpaper so a picker confirm cannot wipe the live desktop image.
set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 1
fi

real="$(realpath "$FILE")"
if [ ! -f "$real" ]; then
    exit 1
fi

pic="$(xdg-user-dir PICTURES 2>/dev/null || true)"
if [ -z "${pic:-}" ] || [ "$pic" = "$HOME" ]; then
    pic="$HOME/Pictures"
fi

ok=0
for d in \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Pictures/Wallpaper" \
    "$pic/Wallpapers" \
    "$pic/Wallpaper"
do
    [ -d "$d" ] || continue
    prefix="$(realpath "$d")"
    case "$real" in
        "$prefix"/*)
            ok=1
            break
            ;;
    esac
done
if [ "$ok" -ne 1 ]; then
    exit 2
fi

state="${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper"
if [ -f "$state" ]; then
    cur="$(cat "$state" || true)"
    if [ -n "${cur:-}" ] && [ -e "$cur" ]; then
        cur_real="$(realpath "$cur")"
        if [ "$real" = "$cur_real" ]; then
            exit 3
        fi
    fi
fi

rm -- "$real"
