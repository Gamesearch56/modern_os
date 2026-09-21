#!/usr/bin/env bash
# Render hypridle.conf from config.json idle timings and restart hypridle
# only when the file changes. Nested JsonObject ints in QML do not always
# notify; disk JSON is the source of truth.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: hypridle-apply.sh [--no-restart]

Reads general.idleTimings from $XDG_CONFIG_HOME/modern/config.json and
writes $XDG_CONFIG_HOME/hypr/hypridle.conf. Restarts hypridle when the
rendered file differs, or starts it if it is not running.
EOF
}

RESTART=1
for arg in "$@"; do
    case "$arg" in
        -h | --help)
            usage
            exit 0
            ;;
        --no-restart)
            RESTART=0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${MODERN_CONFIG_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"
CONF="${MODERN_HYPRIDLE_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf}"
BRIGHT="${MODERN_BRIGHTNESS_SH:-$HERE/brightness.sh}"
LOCK_DIR="${MODERN_HYPRIDLE_LOCK_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"

clamp() {
    local v="$1" d="$2"
    if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -eq 0 ]; then
        printf '0\n'
        return
    fi
    if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le 86400 ]; then
        printf '%s\n' "$v"
    else
        printf '%s\n' "$d"
    fi
}

read_sec() {
    local key="$1" default="$2" raw=""
    if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
        raw="$(jq -r --arg k "$key" '.general.idleTimings[$k] // empty' "$CFG" 2>/dev/null || true)"
    fi
    clamp "$raw" "$default"
}

# 0 = Never in Settings. hypridle treats timeout 0 as immediate, so skip.
append_listener() {
    local timeout="$1" on_timeout="$2" on_resume="${3:-}"
    [ "$timeout" -gt 0 ] || return 0
    printf '%s\n' "listener {" "    timeout = ${timeout}" "    on-timeout = ${on_timeout}"
    if [ -n "$on_resume" ]; then
        printf '%s\n' "    on-resume = ${on_resume}"
    fi
    printf '%s\n' "}"
}

dim="$(read_sec dimSec 120)"
off="$(read_sec screenOffSec 300)"
lock="$(read_sec lockSec 600)"
suspend="$(read_sec suspendSec 1800)"

mkdir -p "$(dirname -- "$CONF")" "$LOCK_DIR"
tmp="$(mktemp "${CONF}.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT
{
    printf '%s\n' \
        "general {" \
        "    lock_cmd = qs -c modern ipc call session lock" \
        "    before_sleep_cmd = qs -c modern ipc call session lock" \
        "    after_sleep_cmd = hyprctl dispatch dpms on" \
        "    ignore_dbus_inhibit = false" \
        "}"
    append_listener "$dim" "${BRIGHT} dim" "${BRIGHT} undim"
    append_listener "$off" "hyprctl dispatch dpms off" "hyprctl dispatch dpms on"
    append_listener "$lock" "qs -c modern ipc call session lock"
    append_listener "$suspend" "systemctl suspend"
} >"$tmp"

changed=1
if [ -f "$CONF" ] && cmp -s "$tmp" "$CONF"; then
    changed=0
    rm -f -- "$tmp"
    trap - EXIT
else
    mv -f -- "$tmp" "$CONF"
    trap - EXIT
fi

if [ "$RESTART" -eq 0 ]; then
    exit 0
fi

command -v hypridle >/dev/null 2>&1 || exit 0

# Close fd 8 in the child. Holding the flock fd in a long-lived
# hypridle makes the next apply (reload_ui) wait forever.
start_hypridle() {
    nohup hypridle >/dev/null 2>&1 8>&- &
    disown $! 2>/dev/null || true
}

mkdir -p "$LOCK_DIR"
{
    flock -w 2 8 || exit 0
    if [ "$changed" -eq 0 ]; then
        pgrep -x hypridle >/dev/null 2>&1 && exit 0
        start_hypridle
        exit 0
    fi
    pkill -x hypridle 2>/dev/null || true
    start_hypridle
} 8>"$LOCK_DIR/modern-hypridle-apply.lock"
