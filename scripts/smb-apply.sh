#!/usr/bin/env bash
# Privileged Samba start/stop. One pkexec from Settings. enable rewrites
# the share from the existing path (or argv folder) then starts units.
set -euo pipefail

export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="${MODERN_SMB_SETUP:-$HERE/smb-setup.sh}"
SYSTEMCTL="${MODERN_SMB_SYSTEMCTL:-/usr/bin/systemctl}"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: smb-apply.sh enable|disable [PATH]\n' >&2
    exit 2
fi

cmd="$1"
path="${2:-}"

start_unit() {
    local u="$1"
    "$SYSTEMCTL" list-unit-files "$u" >/dev/null 2>&1 || return 0
    "$SYSTEMCTL" enable --now "$u"
}

stop_unit() {
    local u="$1"
    "$SYSTEMCTL" list-unit-files "$u" >/dev/null 2>&1 || return 0
    "$SYSTEMCTL" disable --now "$u" >/dev/null 2>&1 || true
}

case "$cmd" in
    enable)
        if [ -n "$path" ]; then
            "$SETUP" "$path"
        else
            "$SETUP"
        fi
        "$SYSTEMCTL" daemon-reload >/dev/null 2>&1 || true
        start_unit smb.service
        start_unit nmb.service
        start_unit wsdd.service
        ;;
    disable)
        stop_unit wsdd.service
        stop_unit nmb.service
        stop_unit smb.service
        ;;
    *)
        printf 'usage: smb-apply.sh enable|disable [PATH]\n' >&2
        exit 2
        ;;
esac
