#!/usr/bin/env bash
# Disk-cache path + resize for wallpaper picker/gallery tiles.
# Source from scripts/, never execute. Longest edge matches ~2× the
# picker tile so a 2× display still crops from a small JPEG.

wallpaper_thumb_dir() {
    printf '%s/modern/wallpaper-thumbs' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

wallpaper_thumb_key() {
    local src="${1:-}"
    local st
    [ -n "$src" ] || return 1
    st="$(stat -c '%Y %s' "$src" 2>/dev/null || true)"
    [ -n "$st" ] || return 1
    printf '%s %s v2' "$src" "$st" | sha256sum | awk '{print $1}'
}

wallpaper_thumb_path() {
    local src="${1:-}"
    local key
    key="$(wallpaper_thumb_key "$src")" || return 1
    printf '%s/%s.jpg' "$(wallpaper_thumb_dir)" "$key"
}

wallpaper_thumb_make() {
    local src="${1:-}" dest="${2:-}"
    local dir tmp
    [ -n "$src" ] && [ -n "$dest" ] && [ -f "$src" ] || return 1
    dir="$(dirname "$dest")"
    mkdir -p "$dir"
    tmp="${dest}.tmp.$$.jpg"
    if command -v magick >/dev/null 2>&1; then
        magick -- "$src" -resize '512x512>' -quality 80 "$tmp" || {
            rm -f "$tmp"
            return 1
        }
    elif command -v convert >/dev/null 2>&1; then
        convert -- "$src" -resize '512x512>' -quality 80 "$tmp" || {
            rm -f "$tmp"
            return 1
        }
    else
        return 1
    fi
    mv -f "$tmp" "$dest"
}
