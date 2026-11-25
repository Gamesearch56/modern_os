#!/usr/bin/env bash
# Remove a file from the user wallpaper library. Refuses shipped
# copies under ~/.config/modern/wallpapers and the currently applied
# wallpaper so a picker confirm cannot wipe the live desktop image.
set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

real="$(realpath "$FILE")"
if [ ! -f "$real" ]; then
    exit 1
fi

shipped="$(realpath "${XDG_CONFIG_HOME:-$HOME/.config}/modern/wallpapers" 2>/dev/null || true)"
ok=0
while IFS= read -r d; do
    [ -d "$d" ] || continue
    prefix="$(realpath "$d")"
    [ -n "$prefix" ] || continue
    if [ -n "$shipped" ] && [ "$prefix" = "$shipped" ]; then
        continue
    fi
    case "$real" in
        "$prefix"/*)
            ok=1
            break
            ;;
    esac
done < <(xdg_wallpaper_library_dirs)
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
