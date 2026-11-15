#!/usr/bin/env bash
# Wine's driver services ignore SIGTERM. Started from a terminal, they
# stay in that app scope and hold the user manager at
# "A stop job is running" until the stop timeout. Session exit SIGKILLs
# only these comm names (TASK_COMM_LEN, 15 characters).
set -euo pipefail

proc_root="${WINE_REAP_PROC:-/proc}"
dry="${WINE_REAP_DRY:-0}"
if [ -n "${WINE_REAP_NAMES:-}" ]; then
    # Intentional split: tests pass a space-separated comm list.
    # shellcheck disable=SC2206
    names=($WINE_REAP_NAMES)
else
    names=(winedevice.exe wineserver plugplay.exe services.exe rpcss.exe wineboot.exe)
fi

uid="$(id -u)"

is_target() {
    local comm="$1" name
    for name in "${names[@]}"; do
        [ "$comm" = "$name" ] && return 0
    done
    return 1
}

reap_once() {
    local dir pid comm uid_line
    shopt -s nullglob
    for dir in "$proc_root"/[0-9]*; do
        pid="${dir##*/}"
        [ "$pid" -gt 1 ] 2>/dev/null || continue
        comm="$(tr -d '\n' <"$dir/comm" 2>/dev/null || true)"
        is_target "$comm" || continue
        uid_line="$(awk '/^Uid:/{print $2; exit}' "$dir/status" 2>/dev/null || true)"
        [ "$uid_line" = "$uid" ] || continue
        if [ "$dry" = 1 ]; then
            printf '%s\n' "$pid"
            continue
        fi
        kill -KILL "$pid" 2>/dev/null || true
    done
}

reap_once
# wineserver can spawn another winedevice between the scan and the kill.
if [ "$dry" != 1 ]; then
    reap_once
fi
