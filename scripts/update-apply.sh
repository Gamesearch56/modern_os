#!/usr/bin/env bash
# Privileged system update for Settings → Update. One pkexec from
# `modern update` so snapper + pacman share a single auth prompt.
set -euo pipefail

SNAPSHOT=0
for arg in "$@"; do
    case "$arg" in
        --snapshot)
            SNAPSHOT=1
            ;;
        --no-snapshot)
            SNAPSHOT=0
            ;;
        -h | --help)
            printf 'usage: update-apply.sh [--snapshot|--no-snapshot]\n' >&2
            exit 0
            ;;
        *)
            printf 'usage: update-apply.sh [--snapshot|--no-snapshot]\n' >&2
            exit 2
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    printf 'update-apply: must run as root (pkexec)\n' >&2
    exit 1
fi

if [ "$SNAPSHOT" -eq 1 ]; then
    if command -v snapper >/dev/null 2>&1 \
        && snapper list-configs >/dev/null 2>&1 \
        && snapper list-configs 2>/dev/null | grep -q root; then
        snapper -c root create --description "ModernOS Update"
    fi
fi

exec /usr/bin/pacman -Syu --noconfirm
