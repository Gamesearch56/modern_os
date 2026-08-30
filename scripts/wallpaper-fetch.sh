#!/usr/bin/env bash
# Download an image URL into ~/Pictures/Wallpapers. Only image MIME types.
# Used by Services/Wallpaper.qml — Modules never curl or write the file.
set -euo pipefail

URL="${1:-}"
DEST_DIR="${2:-}"
if [ -z "$URL" ]; then
    echo "Usage: wallpaper-fetch.sh URL [directory]" >&2
    exit 2
fi
case "$URL" in
    http://* | https://*) ;;
    *)
        echo "wallpaper-fetch: not an http(s) URL" >&2
        exit 2
        ;;
esac

if [ -z "$DEST_DIR" ]; then
    pic="$(xdg-user-dir PICTURES 2>/dev/null || true)"
    if [ -z "${pic:-}" ] || [ "$pic" = "$HOME" ]; then
        pic="$HOME/Pictures"
    fi
    DEST_DIR="$pic/Wallpapers"
fi
mkdir -p "$DEST_DIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL --max-time 90 \
    -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36" \
    -o "$tmp" -- "$URL"

if [ ! -s "$tmp" ]; then
    echo "wallpaper-fetch: empty download" >&2
    exit 1
fi

mime=""
if command -v file >/dev/null 2>&1; then
    mime="$(file -b --mime-type "$tmp" || true)"
fi
ext=""
case "$mime" in
    image/jpeg | image/jpg) ext="jpg" ;;
    image/png) ext="png" ;;
    image/webp) ext="webp" ;;
esac
if [ -z "$ext" ]; then
    echo "wallpaper-fetch: not an image (${mime:-unknown})" >&2
    exit 2
fi

path_part="${URL%%\?*}"
path_part="${path_part%%#*}"
base="$(basename "$path_part")"
stem="${base%.*}"
stem="$(printf '%s' "$stem" | tr -cd '[:alnum:]._-')"
if [ -z "$stem" ] || [ "$stem" = "." ] || [ "$stem" = ".." ]; then
    stem="wallpaper-$(date +%Y%m%d-%H%M%S)"
fi

dest_file="$DEST_DIR/${stem}.${ext}"
if [ -e "$dest_file" ]; then
    i=1
    while [ -e "$DEST_DIR/${stem}-$i.$ext" ]; do
        i=$((i + 1))
    done
    dest_file="$DEST_DIR/${stem}-$i.$ext"
fi

cp -- "$tmp" "$dest_file"
printf '%s\n' "$(realpath "$dest_file")"
