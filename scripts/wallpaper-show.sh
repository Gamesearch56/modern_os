#!/usr/bin/env bash
# Live wallpaper swap via awww. Duration is Motion.longMs (400), scaled
# by motion.scale. Optional $2 is the awww transition type (Settings
# preview); otherwise design.wallpaperTransition from config.json.
# Optional $3 is the shell's wallpaper generation. The crop is finished
# before awww runs, and the start line is written at that moment so the
# shell can move its palette with the transition instead of when matugen
# happens to finish. Filter/resize stay Lanczos3 crop.
set -euo pipefail

IMAGE="${1:-}"
KIND="${2:-}"
GEN="${3:-}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
MARK="$STATE_DIR/wallpaper-transition"
PREP=""
SHOW="$IMAGE"
[ -n "$IMAGE" ] && [ -f "$IMAGE" ] || exit 1

mark() {
    [ -n "$GEN" ] || return 0
    mkdir -p "$STATE_DIR"
    printf '%s %s %s %s\n' "$1" "$2" "$GEN" "$(date +%s%N)" > "$MARK"
}

finish_mark() {
    mark "done" 0
    if [ -n "$PREP" ]; then
        rm -f "$PREP"
        PREP=""
    fi
}
trap finish_mark EXIT

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

# Crop to the largest screen before awww, so the transition itself
# starts when the start line is written. awww's own Lanczos runs before
# its timer and would let a finished palette land on the old picture.
prepare_frame() {
    command -v magick >/dev/null 2>&1 || return 0
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0
    local wh w h tmp
    wh="$(hyprctl monitors -j 2>/dev/null | jq -r 'if type == "array" and length > 0 then (max_by((.width | tonumber) * (.height | tonumber)) | "\(.width) \(.height)") else empty end' || true)"
    [ -n "$wh" ] || return 0
    w="${wh%% *}"
    h="${wh#* }"
    case "$w" in ''|*[!0-9]*) return 0 ;; esac
    case "$h" in ''|*[!0-9]*) return 0 ;; esac
    tmp="$(mktemp --suffix=.jpg)"
    if magick "$IMAGE" -filter Lanczos -resize "${w}x${h}^" -gravity center -extent "${w}x${h}" -quality 92 "$tmp"; then
        PREP="$tmp"
        SHOW="$tmp"
    else
        rm -f "$tmp"
    fi
}

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

dur="0"
if awk -v s="$scale" 'BEGIN { exit !(s + 0 > 0) }'; then
    dur="$(awk -v s="$scale" 'BEGIN { printf "%.3f", 0.4 * s }')"
fi

prepare_frame
mark start "$dur"

filter=(--filter Lanczos3 --resize crop --crop-gravity center)
if [ -n "$PREP" ]; then
    filter=(--filter Nearest --resize crop --crop-gravity center)
fi
if awk -v s="$scale" 'BEGIN { exit !(s + 0 > 0) }'; then
    awww img "$SHOW" "${filter[@]}" --transition-type "$KIND" \
        --transition-duration "$dur" --transition-fps 60
else
    awww img "$SHOW" "${filter[@]}"
fi
