#!/usr/bin/env bash
# Bridge the desktop clipboard and gamescope's X clipboard.
# Source the starters, or run: wow-clipboard.sh run <wayland> <xdisplay>
# shellcheck disable=SC2317

wow_clipboard_bin() {
    local dir src bin
    dir="${XDG_CACHE_HOME:-$HOME/.cache}/modern"
    src="${WOW_CLIPBOARD_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xclipboard.c}"
    bin="$dir/xclipboard"
    mkdir -p "$dir"
    if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
        command -v gcc >/dev/null 2>&1 || return 1
        gcc -O2 -s -o "$bin" "$src" -lX11 -lXfixes || return 1
    fi
    printf '%s\n' "$bin"
}

wow_clipboard_pidfile() {
    printf '%s\n' "${XDG_RUNTIME_DIR:-/tmp}/modern/wow-clipboard.pid"
}

wow_clipboard_stop() {
    local pidfile pid
    pidfile="$(wow_clipboard_pidfile)"
    [ -f "$pidfile" ] || return 0
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
}

wow_clipboard_run() {
    local host="$1" xdisp="$2" bin stamp pidfile to_game to_host
    set -euo pipefail
    set -m
    bin="$(wow_clipboard_bin)" || return 0
    stamp="${XDG_RUNTIME_DIR:-/tmp}/modern/wow-clipboard.txt"
    pidfile="$(wow_clipboard_pidfile)"
    mkdir -p "$(dirname "$stamp")"
    printf '%s\n' "$$" >"$pidfile"
    trap 'kill $(jobs -p) 2>/dev/null || true; exit 0' TERM INT
    # shellcheck disable=SC2016
    WAYLAND_DISPLAY="$host" wl-paste --watch sh -c '
        incoming=$(mktemp)
        cat >"$incoming"
        stamp=$1 bin=$2 xdisp=$3
        if cmp -s "$incoming" "$stamp"; then
            rm -f "$incoming"
            exit 0
        fi
        cp "$incoming" "$stamp"
        DISPLAY=$xdisp "$bin" set <"$incoming"
        rm -f "$incoming"
    ' sh "$stamp" "$bin" "$xdisp" >/dev/null 2>&1 &
    to_game=$!
    (
        DISPLAY="$xdisp" "$bin" watch 2>/dev/null | while IFS= read -r -d '' data; do
            prev=$(cat "$stamp" 2>/dev/null || true)
            [ "$data" = "$prev" ] && continue
            printf '%s' "$data" >"$stamp"
            printf '%s' "$data" | WAYLAND_DISPLAY="$host" wl-copy
        done
    ) >/dev/null 2>&1 &
    to_host=$!
    trap 'kill -- -"$to_game" -"$to_host" 2>/dev/null || true; exit 0' TERM INT
    wait
}

# $1 host WAYLAND_DISPLAY, $2 gamescope DISPLAY (for example :1).
wow_clipboard_start() {
    local host="$1" xdisp="$2" self
    command -v wl-paste >/dev/null 2>&1 || return 0
    command -v wl-copy >/dev/null 2>&1 || return 0
    command -v setsid >/dev/null 2>&1 || return 0
    [ -n "$host" ] && [ -n "$xdisp" ] || return 0
    wow_clipboard_bin >/dev/null || return 0
    wow_clipboard_stop
    self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    setsid -f "$self" run "$host" "$xdisp" >/dev/null 2>&1
}

if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "run" ]; then
    wow_clipboard_run "${2:-}" "${3:-}"
fi
