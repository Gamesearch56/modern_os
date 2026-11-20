#!/usr/bin/env bash
# Install a picture as this account's face (~/.face) and refresh the
# login snapshot. The file manager chooses the file. "clear" removes it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -n "${HOME:-}" ] || exit 2

# The shell asks which portrait is installed. Printing it avoids treating
# a deleted file as the current one.
if [ "${1:-}" = "--which" ]; then
    if [ -f "$HOME/.face" ]; then
        printf 'have %s\n' "$HOME/.face"
    elif [ -f "$HOME/.face.icon" ]; then
        printf 'have %s\n' "$HOME/.face.icon"
    else
        printf 'none\n'
    fi
    exit 0
fi

# Header only. The preview must not decode the whole photo on the shell thread.
if [ "${1:-}" = "--size" ]; then
    src="${2:-}"
    [ -n "$src" ] && [ -f "$src" ] || exit 2
    if command -v magick >/dev/null 2>&1; then
        magick identify -ping -format '%w %h %[EXIF:Orientation]\n' "$src"
    elif command -v identify >/dev/null 2>&1; then
        identify -ping -format '%w %h %[EXIF:Orientation]\n' "$src"
    else
        exit 2
    fi
    exit 0
fi

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
    exit 3
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
