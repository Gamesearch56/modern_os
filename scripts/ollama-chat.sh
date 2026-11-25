#!/usr/bin/env bash
# Stream one Ollama chat. Web search stays in this process so the API
# key is never sent to the model.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    printf '%s\n' '{"error":"bad request"}'
    exit 1
fi

exec python3 -u "$ROOT/lib/ollama_chat.py" "$1"
