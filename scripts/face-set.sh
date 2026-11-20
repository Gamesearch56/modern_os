#!/usr/bin/env bash
# Install a picture as this account's face (~/.face) and refresh the
# login snapshot. With no path, a file chooser opens. "clear" removes it.
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

[ -n "${HOME:-}" ] || exit 2

sync_faces() {
    if [ -f "$SCRIPT_DIR/session-users-sync.sh" ]; then
        bash "$SCRIPT_DIR/session-users-sync.sh" || true
    fi
}

if [ "${1:-}" = "clear" ]; then
    rm -f "$HOME/.face" "$HOME/.face.icon"
    sync_faces
    exit 0
fi

# The circle the user framed. ImageMagick writes the square that every
# face view clips back into a circle.
if [ "${1:-}" = "--edit" ]; then
    chosen="${2:-}"
    rotate="${3:-}"
    crop="${4:-}"
    case "$rotate" in
        0 | 90 | 180 | 270) ;;
        *) exit 2 ;;
    esac
    if ! [[ "$crop" =~ ^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$ ]]; then
        exit 2
    fi
    crop_w="${crop%%x*}"
    crop_rest="${crop#*x}"
    crop_h="${crop_rest%%+*}"
    if [ "$crop_w" -lt 1 ] || [ "$crop_h" -lt 1 ]; then
        exit 2
    fi
fi

if [ "${1:-}" != "--edit" ]; then
    chosen="${1:-}"
fi
if [ -z "${chosen:-}" ]; then
    start="$(xdg_user_dir PICTURES Pictures)"
    [ -d "$start" ] || start="$HOME"
    title="$(t settings.users.chooseFace)"
    if command -v kdialog >/dev/null 2>&1; then
        chosen="$(kdialog --title "$title" --getopenfilename "$start/" \
            "$(t settings.users.faceImages) (*.jpg *.jpeg *.png *.webp)" || true)"
    elif command -v zenity >/dev/null 2>&1; then
        chosen="$(zenity --file-selection --title="$title" --filename="${start}/" \
            --file-filter="$(t settings.users.faceImages) | *.jpg *.jpeg *.png *.webp *.JPG *.JPEG *.PNG *.WEBP" || true)"
    else
        t settings.users.faceChooser >&2
        exit 3
    fi
fi

if [ -z "$chosen" ]; then
    exit 1
fi
if [ ! -f "$chosen" ]; then
    exit 2
fi

src="$(realpath "$chosen")"
mime=""
if command -v file >/dev/null 2>&1; then
    mime="$(file -b --mime-type "$src" || true)"
fi
case "$mime" in
    image/jpeg | image/jpg | image/png | image/x-png | image/webp | image/gif | image/bmp | image/x-bmp | image/tiff | image/avif | image/heic | image/heif) ;;
    *) exit 2 ;;
esac

bytes="$(stat -c %s "$src")"
# A portrait does not need a full camera original.
if [ "$bytes" -gt 20971520 ]; then
    exit 2
fi

tmp="$(mktemp "$HOME/.face.XXXXXX")"
cleanup() {
    if [ -n "${tmp:-}" ] && [ -f "$tmp" ]; then
        rm -f "$tmp"
    fi
}
trap cleanup EXIT
if [ "${1:-}" = "--edit" ]; then
    draw=( -auto-orient -rotate "$rotate" -crop "$crop" +repage -resize 512x512^ -gravity center -extent 512x512 -quality 90 )
    if command -v magick >/dev/null 2>&1; then
        magick "$src" "${draw[@]}" "jpeg:$tmp"
    elif command -v convert >/dev/null 2>&1; then
        convert "$src" "${draw[@]}" "jpeg:$tmp"
    else
        exit 2
    fi
else
    cp -- "$src" "$tmp"
fi
chmod 644 "$tmp"
mv -f "$tmp" "$HOME/.face"
tmp=""
rm -f "$HOME/.face.icon"
sync_faces
printf '%s\n' "$HOME/.face"
