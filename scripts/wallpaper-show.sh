#!/usr/bin/env bash
# Live wallpaper swap via awww. Kept tiny so the picker can fire it
# before theme-apply.sh / matugen / ImageMagick start — those were
# stalling the fade for seconds. Duration is Motion.longMs (400).
# Optional $2 is the awww transition type (Settings preview); otherwise
# design.wallpaperTransition from config.json.
set -euo pipefail

IMAGE="${1:-}"
KIND="${2:-}"
[ -n "$IMAGE" ] && [ -f "$IMAGE" ] || exit 1

if ! command -v awww >/dev/null 2>&1 || ! pgrep -x awww-daemon >/dev/null 2>&1; then
    printf '[wallpaper-show] WARN awww-daemon not running\n' >&2
    exit 0
fi

DEFAULT_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.default.json"
LIVE_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
scale="1"
if command -v jq >/dev/null 2>&1; then
    if [ -f "$DEFAULT_JSON" ] && [ -f "$LIVE_JSON" ]; then
        scale="$(jq -r -s '.[0] * .[1] | .motion.scale // 1' "$DEFAULT_JSON" "$LIVE_JSON")"
    elif [ -f "$LIVE_JSON" ]; then
        scale="$(jq -r '.motion.scale // 1' "$LIVE_JSON")"
    elif [ -f "$DEFAULT_JSON" ]; then
        scale="$(jq -r '.motion.scale // 1' "$DEFAULT_JSON")"
    fi
fi

if [ -z "$KIND" ] && command -v jq >/dev/null 2>&1; then
    if [ -f "$DEFAULT_JSON" ] && [ -f "$LIVE_JSON" ]; then
        KIND="$(jq -r -s '.[0] * .[1] | .design.wallpaperTransition // "fade"' "$DEFAULT_JSON" "$LIVE_JSON")"
    elif [ -f "$LIVE_JSON" ]; then
        KIND="$(jq -r '.design.wallpaperTransition // "fade"' "$LIVE_JSON")"
    elif [ -f "$DEFAULT_JSON" ]; then
        KIND="$(jq -r '.design.wallpaperTransition // "fade"' "$DEFAULT_JSON")"
    fi
fi

case "$KIND" in
    none|simple|fade|left|right|top|bottom|wipe|wave|grow|center|any|outer|random) ;;
    *) KIND="fade" ;;
esac

if awk -v s="$scale" 'BEGIN { exit !(s + 0 > 0) }'; then
    dur="$(awk -v s="$scale" 'BEGIN { printf "%.3f", 0.4 * s }')"
    exec awww img "$IMAGE" --transition-type "$KIND" --transition-duration "$dur" --transition-fps 60
fi
exec awww img "$IMAGE"
