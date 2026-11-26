#!/usr/bin/env bash
# Copy the shipped wallpapers into the XDG library as real files and
# build their picker thumbnails. A symlink or a non-image left under
# the same name is what the picker shows, and it hides the shipped
# picture. A real image already there is left alone.
set -euo pipefail

SHIPPED="${1:-}"
LIBRARY="${2:-}"
if [ -z "$SHIPPED" ] || [ -z "$LIBRARY" ] || [ ! -d "$SHIPPED" ]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"
# shellcheck source=lib/wallpaper-thumb.sh
source "$SCRIPT_DIR/lib/wallpaper-thumb.sh"

mkdir -p "$LIBRARY"
thumbs=()
for f in "$SHIPPED"/*; do
    [ -f "$f" ] || continue
    xdg_wallpaper_bytes "$f" || continue
    dest="$LIBRARY/$(basename "$f")"
    if [ -e "$dest" ] && [ ! -L "$dest" ] && xdg_wallpaper_bytes "$dest"; then
        thumbs+=("$dest")
        continue
    fi
    cp -L -- "$f" "$dest"
    thumbs+=("$dest")
done

if [ "${#thumbs[@]}" -eq 0 ]; then
    exit 0
fi
if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
    exit 0
fi
for src in "${thumbs[@]}"; do
    dest="$(wallpaper_thumb_path "$src")" || continue
    if [ ! -f "$dest" ]; then
        wallpaper_thumb_make "$src" "$dest" || true
    fi
done
