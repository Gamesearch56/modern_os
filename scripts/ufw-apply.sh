#!/usr/bin/env bash
# Privileged UFW mutate. Settings calls this once via pkexec so enable
# does not open four Phylax prompts (defaults + --force enable).
# enable/disable take no extra argv; never interpolates caller strings.
set -euo pipefail

UFW=/usr/bin/ufw
export LC_ALL=C

if [ ! -x "$UFW" ]; then
    printf 'ufw missing\n' >&2
    exit 1
fi

cmd="${1:-}"
if [ "$#" -ne 1 ]; then
    printf 'usage: ufw-apply.sh enable|disable\n' >&2
    exit 2
fi

case "$cmd" in
    enable)
        "$UFW" default deny incoming
        "$UFW" default allow outgoing
        "$UFW" default deny routed
        exec "$UFW" --force enable
        ;;
    disable)
        exec "$UFW" disable
        ;;
    *)
        printf 'usage: ufw-apply.sh enable|disable\n' >&2
        exit 2
        ;;
esac
