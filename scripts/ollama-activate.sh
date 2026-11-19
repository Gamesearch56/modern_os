#!/usr/bin/env bash
# Start the Ollama service from Settings. No arguments. Starts the
# password dialog first, then pkexecs the root-only enable script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/polkit-agent.sh
source "$ROOT/lib/polkit-agent.sh"

if [ "$#" -ne 0 ]; then
    printf 'usage: ollama-activate.sh\n' >&2
    exit 2
fi

if [ "${OLLAMA_ACTIVATE_DRY:-}" = "1" ]; then
    printf '%s\n' 'pkexec ollama-enable.sh'
    exit 0
fi

if [ ! -x /usr/bin/pkexec ]; then
    printf 'ollama-activate: pkexec is missing\n' >&2
    exit 1
fi
if ! ensure_polkit_agent; then
    printf 'ollama-activate: password dialog is not available\n' >&2
    exit 6
fi
exec /usr/bin/pkexec "$ROOT/ollama-enable.sh"
