#!/usr/bin/env bash
# Pull the everyday model once the local daemon answers.
# qwen3:4b is the daily chat model that still fits a laptop with little
# memory. The assistant turns thinking off and keeps the context short,
# so the extra size stays usable on a slow processor. No model argument:
# this cannot be pointed at a different download.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ollama-quiet.sh
source "$ROOT/lib/ollama-quiet.sh"

if [ "$#" -ne 0 ]; then
    printf 'usage: ollama-pull.sh\n' >&2
    exit 2
fi

model="qwen3:4b"
OLLAMA="${MODERN_OLLAMA_BIN:-ollama}"
CURL="${MODERN_OLLAMA_CURL:-curl}"

if [ "${OLLAMA_PULL_DRY:-}" = "1" ]; then
    printf '%s\n' "$model"
    exit 0
fi

ready=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 \
         21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40; do
    if "$CURL" -sf --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null; then
        ready=1
        break
    fi
    sleep 0.5
done
if [ "$ready" -ne 1 ]; then
    printf 'ollama-pull: service is not answering\n' >&2
    exit 1
fi

ollama_quiet_pull "$OLLAMA" "$model" "$ROOT/lib/ollama_progress.py"
