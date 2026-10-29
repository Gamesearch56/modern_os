#!/usr/bin/env bash
# Copy an image into XDG PICTURES/Wallpapers via a file chooser.
# Refuses a pick whose realpath already lives in that destination folder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"
# shellcheck source=../install/lib/i18n.sh
source "$REPO_ROOT/install/lib/i18n.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
    I18N_LANG="$(jq -r '.language.ui // "en"' "$CFG")"
    [ "$I18N_LANG" = "de" ] || I18N_LANG="en"
fi

DEST="$(xdg_wallpapers_dir)"
mkdir -p "$DEST"
DEST_REAL="$(realpath "$DEST")"

chosen=""
if command -v kdialog >/dev/null 2>&1; then
    chosen="$(kdialog --getopenfilename "$HOME/" \
        "$(t wallpaper.importImages) (*.jpg *.jpeg *.png *.webp)" || true)"
elif command -v zenity >/dev/null 2>&1; then
    chosen="$(zenity --file-selection --title="$(t wallpaper.importTitle)" --filename="$HOME/" \
        --file-filter="$(t wallpaper.importImages) | *.jpg *.jpeg *.png *.webp *.JPG *.JPEG *.PNG *.WEBP" \
        --file-filter="$(t wallpaper.importAll) | *" || true)"
else
    t wallpaper.needChooser >&2
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
