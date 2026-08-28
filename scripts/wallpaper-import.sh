#!/usr/bin/env bash
# Copy an image into ~/Pictures/Wallpapers via a file chooser.
# Refuses a pick whose realpath already lives in that destination folder.
set -euo pipefail

pic="$(xdg-user-dir PICTURES 2>/dev/null || true)"
if [ -z "${pic:-}" ] || [ "$pic" = "$HOME" ]; then
    pic="$HOME/Pictures"
fi
DEST="$pic/Wallpapers"
mkdir -p "$DEST"
DEST_REAL="$(realpath "$DEST")"

chosen=""
if command -v zenity >/dev/null 2>&1; then
    chosen="$(zenity --file-selection --title="Add wallpaper" --filename="$HOME/" \
        --file-filter='Images | *.jpg *.jpeg *.png *.webp *.JPG *.JPEG *.PNG *.WEBP' \
        --file-filter='All files | *' || true)"
elif command -v kdialog >/dev/null 2>&1; then
    chosen="$(kdialog --getopenfilename "$HOME/" \
        'Image files (*.jpg *.jpeg *.png *.webp)' || true)"
else
    echo "wallpaper-import: need zenity or kdialog" >&2
    exit 3
fi

if [ -z "$chosen" ]; then
    exit 1
fi
if [ ! -f "$chosen" ]; then
    echo "wallpaper-import: not a file: $chosen" >&2
    exit 3
fi

src="$(realpath "$chosen")"
src_dir="$(dirname "$src")"
if [ "$src_dir" = "$DEST_REAL" ]; then
    echo "wallpaper-import: already in library" >&2
    exit 2
fi

base="$(basename "$src")"
dest_file="$DEST/$base"
if [ -e "$dest_file" ]; then
    stem="${base%.*}"
    ext="${base##*.}"
    i=1
    while [ -e "$DEST/${stem}-$i.$ext" ]; do
        i=$((i + 1))
    done
    dest_file="$DEST/${stem}-$i.$ext"
fi

cp -- "$src" "$dest_file"
printf '%s\n' "$(realpath "$dest_file")"
