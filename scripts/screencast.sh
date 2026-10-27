#!/usr/bin/env bash
# Screen recording into screenshots.videoDirectory only (never the
# stills folder). Started/stopped by Services/Recording.qml.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: screencast.sh <region|window|full|stop> [geometry] [output]
EOF
}

MODE="${1:-}"
GEOM_ARG="${2:-}"
OUTPUT_ARG="${3:-}"
if [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ] || [ -z "$MODE" ]; then
    usage
    [ -n "$MODE" ] && exit 0
    exit 2
fi

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/modern"
PIDFILE="$RUNTIME/screencast.pid"
mkdir -p "$RUNTIME"

if [ "$MODE" = "stop" ]; then
    if [ -f "$PIDFILE" ]; then
        pid="$(cat "$PIDFILE")"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -INT "$pid" 2>/dev/null || true
        fi
    fi
    exit 0
fi

command -v wf-recorder >/dev/null 2>&1 || { echo "screencast: wf-recorder not on PATH" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

MODERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
DEFAULT_JSON="$MODERN_DIR/config.default.json"
LIVE_JSON="$MODERN_DIR/config.json"

merged() {
    if [ -f "$LIVE_JSON" ] && [ -f "$DEFAULT_JSON" ]; then
        jq -s '.[0] * .[1]' "$DEFAULT_JSON" "$LIVE_JSON"
    elif [ -f "$LIVE_JSON" ]; then
        cat "$LIVE_JSON"
    elif [ -f "$DEFAULT_JSON" ]; then
        cat "$DEFAULT_JSON"
    else
        echo '{}'
    fi
}

CFG="$(merged)"
DIR="$(expand_home "$(jq -r '.screenshots.videoDirectory // "~/Videos/Recordings"' <<<"$CFG")")"
TEMPLATE="$(jq -r '.screenshots.videoFilenameTemplate // "recording-%Y%m%d-%H%M%S"' <<<"$CFG")"
AUDIO="$(jq -r '.screenshots.recordAudio // true' <<<"$CFG")"

if [ -z "$DIR" ]; then
    DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
fi
mkdir -p "$DIR"

FILE="$DIR/$(date +"$TEMPLATE").mp4"
WF_PID=""

# Invoked from trap INT TERM; shellcheck cannot see that.
# shellcheck disable=SC2317,SC2329
cleanup() {
    trap - INT TERM
    if [ -n "${WF_PID:-}" ]; then
        kill -INT "$WF_PID" 2>/dev/null || true
        wait "$WF_PID" || true
    fi
    rm -f "$PIDFILE"
    if [ -s "$FILE" ]; then
        exit 0
    fi
    exit 1
}
trap cleanup INT TERM

region_to_global() {
    local geom="$1"
    local output="$2"
    local xy size x y w h pos ox oy
    xy="${geom%% *}"
    size="${geom#* }"
    x="${xy%%,*}"
    y="${xy#*,}"
    w="${size%%x*}"
    h="${size#*x}"
    if [ -z "$output" ]; then
        printf '%s\n' "$geom"
        return
    fi
    pos="$(hyprctl monitors -j | jq -r --arg o "$output" '
        .[] | select(.name == $o or .description == $o) | "\(.x) \(.y)"
    ' | head -n1)"
    if [ -z "$pos" ] || [ "$pos" = "null" ]; then
        printf '%s\n' "$geom"
        return
    fi
    ox="${pos%% *}"
    oy="${pos#* }"
    printf '%s,%s %sx%s\n' "$((x + ox))" "$((y + oy))" "$w" "$h"
}

wait_hud_gone() {
    for _ in $(seq 1 24); do
        if ! hyprctl layers -j 2>/dev/null | jq -e '
            [.. | objects | select(.namespace? == "modern-screenshot")] | length > 0
        ' >/dev/null; then
            return 0
        fi
        sleep 0.05
    done
}

# Pulse "default" can be a sink monitor or a stale WirePlumber device
# (disconnected Bluetooth), so name the live microphone. --audio=DEVICE
# must be one argv; -a as a flag with an optional argument drops the name.
audio_source() {
    command -v pactl >/dev/null 2>&1 || return 1
    local src
    src="$(pactl get-default-source 2>/dev/null || true)"
    case "$src" in
        "" | *.monitor) ;;
        *)
            printf '%s\n' "$src"
            return 0
            ;;
    esac
    src="$(pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/ { print $2; exit }')"
    [ -n "$src" ] || return 1
    printf '%s\n' "$src"
}

REC=(wf-recorder -y -f "$FILE")
if [ "$AUDIO" = "true" ]; then
    src=""
    if src="$(audio_source)"; then
        REC+=("--audio=${src}")
        REC+=(--audio-backend=pulse)
    else
        echo "screencast: no microphone; recording video only" >&2
    fi
fi

focused_output() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n1
}

geom=""
case "$MODE" in
    region)
        if [ -z "$GEOM_ARG" ]; then
            echo "screencast: region needs geometry" >&2
            exit 2
        fi
        geom="$(region_to_global "$GEOM_ARG" "$OUTPUT_ARG")"
        wait_hud_gone
        REC+=(-g "$geom")
        ;;
    window)
        wait_hud_gone
        geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        REC+=(-g "$geom")
        ;;
    full)
        wait_hud_gone
        if [ -z "$OUTPUT_ARG" ]; then
            OUTPUT_ARG="$(focused_output)"
        fi
        if [ -z "$OUTPUT_ARG" ]; then
            echo "screencast: no output to record" >&2
            exit 1
        fi
        REC+=(-o "$OUTPUT_ARG")
        ;;
    *)
        echo "screencast: unknown mode '$MODE'" >&2
        usage >&2
        exit 2
        ;;
esac

echo $$ > "$PIDFILE"
printf '%s\n' "$FILE"

"${REC[@]}" >&2 &
WF_PID=$!
wait "$WF_PID" || true
WF_PID=""
rm -f "$PIDFILE"
trap - INT TERM

if [ -s "$FILE" ]; then
    exit 0
fi
exit 1
