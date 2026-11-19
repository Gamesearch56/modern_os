#!/usr/bin/env bash
# ChatGPT account via the OpenAI API. The key is read inside Python
# from gitignored secrets.json or OPENAI_API_KEY — never argv, never printed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
py="$here/lib/chatgpt_api.py"

safe_model() {
    local m="$1"
    if [ "${#m}" -lt 1 ] || [ "${#m}" -gt 96 ]; then
        echo "chatgpt-api: bad model" >&2
        exit 3
    fi
    case "$m" in
        *..* | */* | *' '* | *$'\n'*)
            echo "chatgpt-api: bad model" >&2
            exit 3
            ;;
    esac
    if ! printf '%s' "$m" | grep -Eq '^[A-Za-z0-9._-]+$'; then
        echo "chatgpt-api: bad model" >&2
        exit 3
    fi
}

cmd="${1:-}"
case "$cmd" in
    models)
        exec python3 -u "$py" models
        ;;
    chat)
        model="${2:-}"
        body="${3:-}"
        safe_model "$model"
        if [ ! -f "$body" ]; then
            echo "chatgpt-api: missing body" >&2
            exit 3
        fi
        exec python3 -u "$py" chat "$body"
        ;;
    *)
        echo "Usage: chatgpt-api.sh models|chat MODEL BODY" >&2
        exit 1
        ;;
esac
