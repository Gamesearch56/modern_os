#!/usr/bin/env bash
# Locale XDG folders: stock English capture paths become ~/Bilder/…
# and ~/Pictures/Wallpapers moves next to Nautilus Pictures.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

CFG="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"

xdg_ensure_user_dirs
xdg_migrate_wallpapers

[ -f "$CFG" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

stills_raw="$(jq -r '.screenshots.directory // empty' "$CFG")"
video_raw="$(jq -r '.screenshots.videoDirectory // empty' "$CFG")"
stills="$(xdg_resolve_stills "$stills_raw")"
video="$(xdg_resolve_recordings "$video_raw")"
mkdir -p "$stills" "$video" 2>/dev/null || true

stills_cfg="$(xdg_tilde "$stills")"
video_cfg="$(xdg_tilde "$video")"

if [ "$stills_cfg" = "${stills_raw:-}" ] && [ "$video_cfg" = "${video_raw:-}" ]; then
    exit 0
fi

tmp="$(mktemp "${CFG}.XXXXXX")"
mode="$(stat -c '%a' "$CFG" 2>/dev/null || printf '644')"
if jq --arg s "$stills_cfg" --arg v "$video_cfg" \
    '.screenshots.directory = $s | .screenshots.videoDirectory = $v' "$CFG" >"$tmp"; then
    chmod "$mode" "$tmp"
    mv -f "$tmp" "$CFG"
else
    rm -f "$tmp"
    exit 1
fi
