#!/usr/bin/env bash
# Rate library names against installed memory.
# Usage: ollama-fit.sh RAM_BYTES VRAM_BYTES NAME...
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ram="${1:-}"
vram="${2:-}"
if [[ ! "$ram" =~ ^[0-9]+$ ]] || [[ ! "$vram" =~ ^[0-9]+$ ]]; then
    printf '%s\n' '{}'
    exit 2
fi
shift 2
exec python3 "$ROOT/lib/ollama_fit.py" "$ram" "$vram" "$@"
