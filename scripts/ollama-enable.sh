#!/usr/bin/env bash
# Start the system Ollama unit. Settings pkexecs this. The model
# download stays in ollama-pull.sh so it does not run as root.
set -euo pipefail

if [ "$#" -ne 0 ]; then
    printf 'usage: ollama-enable.sh\n' >&2
    exit 2
fi

# pkexec drops this variable. Tests point it at a fake systemctl.
SYSTEMCTL="${MODERN_OLLAMA_SYSTEMCTL:-}"
if [ -z "$SYSTEMCTL" ]; then
    [ "$(id -u)" -eq 0 ] || {
        printf 'ollama-enable: must run as root (pkexec)\n' >&2
        exit 1
    }
    SYSTEMCTL=/usr/bin/systemctl
fi

# enable refuses a masked unit. Setup is the request to run it, so a
# mask left on the unit is cleared before the service is started.
"$SYSTEMCTL" unmask ollama.service
exec "$SYSTEMCTL" enable --now ollama.service
