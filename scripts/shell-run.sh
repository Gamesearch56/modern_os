#!/usr/bin/env bash
# Keeps the desktop shell running for this Hyprland session. The shell
# owns the lock screen: if it crashes while locked, Hyprland keeps the
# session locked but nothing can unlock it until a new shell takes the
# lock over (misc:allow_session_lock_restore + the locked marker).
#
# A clean exit (0, SIGINT, SIGTERM) or a compositor that is gone ends the
# loop. Repeated crashes inside the window stop it, so a shell that dies
# on start does not spin. Everything is written to quickshell.log.
set -uo pipefail

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/modern/quickshell.log"
QS="${MODERN_SHELL_CMD:-qs}"
MAX_CRASHES="${MODERN_SHELL_MAX_CRASHES:-5}"
WINDOW="${MODERN_SHELL_CRASH_WINDOW:-120}"
DELAY="${MODERN_SHELL_RESTART_DELAY:-1}"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/modern-shell-run.lock"

mkdir -p "$(dirname -- "$LOG")"

note() {
    printf 'shell-run: %s %s\n' "$(date -Is)" "$*" >>"$LOG"
    logger -t modern-shell "$*" 2>/dev/null || true
}

compositor_alive() {
    if [ -n "${MODERN_SHELL_ALIVE:-}" ]; then
        "$MODERN_SHELL_ALIVE"
    else
        timeout 2 hyprctl version >/dev/null 2>&1
    fi
}

other_shell() {
    pgrep -u "$(id -u)" -xf "$QS -c modern" >/dev/null 2>&1 \
        || pgrep -u "$(id -u)" -xf "quickshell -c modern" >/dev/null 2>&1
}

exec 9>"$LOCK"
flock -n 9 || exit 0

# Rotated once per login, under the lock and before a shell holds the
# file open. A tray app that fails a D-Bus property on every update grew
# it to tens of megabytes across sessions; the bug report reads the tail.
if [ "$(wc -c 2>/dev/null <"$LOG" || printf 0)" -gt "${MODERN_SHELL_LOG_CAP:-5242880}" ]; then
    mv -f -- "$LOG" "$LOG.1"
fi

child=0
stop() {
    [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null
    exit 0
}
trap stop TERM INT HUP

crashes=()
while :; do
    "$QS" -c modern >>"$LOG" 2>&1 9>&- &
    child=$!
    wait "$child"
    rc=$?
    child=0
    case "$rc" in
        0 | 130 | 143) exit 0 ;;
    esac
    if ! compositor_alive; then
        exit 0
    fi
    if other_shell; then
        note "shell exited with $rc; another shell is already running"
        exit 0
    fi
    now="$(date +%s)"
    recent=()
    for t in "${crashes[@]}"; do
        [ $((now - t)) -lt "$WINDOW" ] && recent+=("$t")
    done
    recent+=("$now")
    crashes=("${recent[@]}")
    if [ "${#crashes[@]}" -ge "$MAX_CRASHES" ]; then
        note "shell crashed ${#crashes[@]} times in ${WINDOW}s (last exit $rc); not restarting"
        exit 1
    fi
    note "shell exited with $rc; restarting (${#crashes[@]} of $MAX_CRASHES)"
    sleep "$DELAY"
done
