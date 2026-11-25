#!/usr/bin/env bash
# Copy a picture the file manager already chose into the wallpaper folder.
# Refuses a pick whose realpath already lives in that destination folder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

DEST="$(xdg_wallpapers_dir)"
mkdir -p "$DEST"
DEST_REAL="$(realpath "$DEST")"

# The file manager picks the picture. This only copies the chosen file.
chosen="${1:-}"

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

mime=""
if command -v file >/dev/null 2>&1; then
    mime="$(file -b --mime-type "$src" || true)"
fi
case "$mime" in
    image/jpeg | image/jpg | image/png | image/webp) ;;
    *)
        echo "wallpaper-import: not an image (${mime:-unknown})" >&2
        exit 2
        ;;
esac

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
