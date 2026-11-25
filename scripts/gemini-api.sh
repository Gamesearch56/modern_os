#!/usr/bin/env bash
# Gemini Developer API. The key is read from gitignored secrets.json
# or GEMINI_API_KEY — never passed on argv, never printed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

safe_model() {
    local m="$1"
    if [ "${#m}" -lt 1 ] || [ "${#m}" -gt 96 ]; then
        echo "gemini-api: bad model" >&2
        exit 3
    fi
    case "$m" in
        *..* | */* | *' '* | *$'\n'*)
            echo "gemini-api: bad model" >&2
            exit 3
            ;;
    esac
    if ! printf '%s' "$m" | grep -Eq '^[A-Za-z0-9._-]+$'; then
        echo "gemini-api: bad model" >&2
        exit 3
    fi
}

cmd="${1:-}"
case "$cmd" in
    models)
        exec python3 -u "$here/gemini-ndjson.py" models
        ;;
    chat)
        model="${2:-}"
        body="${3:-}"
        safe_model "$model"
        if [ ! -f "$body" ]; then
            echo "gemini-api: missing body" >&2
            exit 3
        fi
        # exec so Stop kills the worker, not a leftover shell.
        exec python3 -u "$here/gemini-ndjson.py" chat "$model" "$body"
        ;;
    *)
        echo "Usage: gemini-api.sh models|chat MODEL BODY" >&2
        exit 1
        ;;
esac
