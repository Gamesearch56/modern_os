#!/usr/bin/env bash
# Live wallpaper swap via awww. Kept tiny so the picker can fire it
# before theme-apply.sh / matugen / ImageMagick start — those were
# stalling the fade for seconds. Duration is Motion.longMs (400).
# Optional $2 is the awww transition type (Settings preview); otherwise
# design.wallpaperTransition from config.json.
# Filter/resize are explicit so picker, theme-apply, and session restore
# share one scaler (Lanczos3 crop) instead of whatever the daemon default
# happens to be that day.
set -euo pipefail

IMAGE="${1:-}"
KIND="${2:-}"
[ -n "$IMAGE" ] && [ -f "$IMAGE" ] || exit 1

if ! command -v awww >/dev/null 2>&1; then
    printf '[wallpaper-show] WARN awww not on PATH\n' >&2
    exit 0
fi

wait_for_awww() {
    local waited=0 limit="${1:-20}" step="${2:-0.1}"
    while ! pgrep -x awww-daemon >/dev/null 2>&1; do
        if [ "$waited" -ge "$limit" ]; then
            printf '[wallpaper-show] WARN awww-daemon not running\n' >&2
            return 1
        fi
        sleep "$step"
        waited=$((waited + 1))
    done
}

# Session restore already has a cropped JPEG. Lanczos3 here is the
# login handoff stall (seconds on a 4K still).
if [ "$KIND" = "none" ]; then
    wait_for_awww 10 0.05 || exit 0
    exec awww img "$IMAGE" --transition-type none
fi

# Autostart launches awww-daemon then this script in the next exec_cmd.
wait_for_awww 20 0.1 || exit 0

QUALITY=(--filter Lanczos3 --resize crop --crop-gravity center)

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
    exec awww img "$IMAGE" "${QUALITY[@]}" --transition-type "$KIND" \
        --transition-duration "$dur" --transition-fps 60
fi
exec awww img "$IMAGE" "${QUALITY[@]}"
