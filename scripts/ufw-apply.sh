#!/usr/bin/env bash
# Privileged UFW mutate. Settings calls this once via pkexec so enable
# does not open four Phylax prompts (defaults + --force enable).
# enable/disable take no extra argv; never interpolates caller strings.
set -euo pipefail

UFW="${UFW_APPLY_BIN:-/usr/bin/ufw}"
ETCDIR="${UFW_APPLY_ETCDIR:-/etc/ufw}"
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

# Settings reads these as the session user. ufw rewrites them as root
# and a 0600 replacement would leave the switch looking off.
publish_rules() {
    local name
    for name in ufw.conf user.rules user6.rules; do
        if [ -f "$ETCDIR/$name" ]; then
            chmod 0644 "$ETCDIR/$name"
        fi
    done
}

# A failed policy change must not skip enable. The package defaults
# already deny incoming; the switch asked for the firewall to be on.
run_default() {
    if "$UFW" default "$@"; then
        return 0
    fi
    printf 'ufw default %s\n' "$*" >&2
    return 1
}

case "$cmd" in
    enable)
        run_default deny incoming || true
        run_default allow outgoing || true
        run_default deny routed || true
        if ! "$UFW" --force enable; then
            publish_rules
            exit 1
        fi
        publish_rules
        ;;
    disable)
        if ! "$UFW" disable; then
            publish_rules
            exit 1
        fi
        publish_rules
        ;;
    *)
        printf 'usage: ufw-apply.sh enable|disable\n' >&2
        exit 2
        ;;
esac
