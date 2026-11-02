#!/usr/bin/env bash
# Runs `modern update` for Settings outside Quickshell. The shell only
# follows the log: a reload (the release rewrites the shell's own files)
# or a crash (Qt upgraded underneath it) used to kill the update through
# its Process and pipe, halfway through pacman.
#
#   start   start unless running, then follow
#   attach  follow a running update, or report one that finished while
#           no shell was watching; exit 75 when there is none
#   reload  restart the UI if the update left that to Settings, which
#           calls it once the finished update has been on screen
# Exit status is the update's.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
LOG="$STATE/update.log"
PIDF="$STATE/update.pid"
RCF="$STATE/update.rc"
RELOAD="$STATE/reload-pending"
NONE=75

running_pid() {
    local pid
    pid="$(cat "$PIDF" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    # A pid from before a reboot may now belong to something else.
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q 'update-run.sh _run' || return 1
    printf '%s\n' "$pid"
}

report() {
    local rc
    rc="$(cat "$RCF" 2>/dev/null || printf '1')"
    rm -f "$RCF"
    [[ "$rc" =~ ^[0-9]+$ ]] || rc=1
    exit "$rc"
}

follow() {
    local pid="$1"
    tail -n +1 -F --pid="$pid" "$LOG" 2>/dev/null || true
    report
}

cmd_run() {
    local rc=0
    MODERN_UPDATE_PROGRESS=1 MODERN_UPDATE_DEFER_RELOAD="$RELOAD" \
        "${MODERN_BIN:-$SCRIPT_DIR/modern}" update </dev/null >>"$LOG" 2>&1 || rc=$?
    printf '%s\n' "$rc" >"$RCF.tmp"
    mv -f "$RCF.tmp" "$RCF"
    rm -f "$PIDF"
}

cmd_start() {
    local pid
    if pid="$(running_pid)"; then
        follow "$pid"
    fi
    mkdir -p "$STATE"
    rm -f "$RCF" "$RELOAD"
    : >"$LOG"
    # Not a process-group leader under &, so setsid does not fork and $!
    # is the update's own pid.
    setsid "$0" _run </dev/null >/dev/null 2>&1 &
    pid=$!
    printf '%s\n' "$pid" >"$PIDF"
    disown "$pid" 2>/dev/null || true
    follow "$pid"
}

cmd_attach() {
    local pid
    if pid="$(running_pid)"; then
        follow "$pid"
    fi
    [ -f "$RCF" ] || exit "$NONE"
    # This shell started after the update finished, so it already runs
    # the new release.
    rm -f "$RELOAD"
    tail -n 1 "$LOG" 2>/dev/null || true
    report
}

cmd_reload() {
    [ -f "$RELOAD" ] || exit 0
    rm -f "$RELOAD"
    setsid -f "${MODERN_RELOAD_UI:-$SCRIPT_DIR/reload-ui.sh}" </dev/null >/dev/null 2>&1
}

case "${1:-}" in
    start) cmd_start ;;
    attach) cmd_attach ;;
    reload) cmd_reload ;;
    _run) cmd_run ;;
    *)
        printf 'usage: update-run.sh start|attach|reload\n' >&2
        exit 2
        ;;
esac
