#!/usr/bin/env bash
# Gemini Developer API. The key is read from gitignored secrets.json
# or GEMINI_API_KEY — never passed on argv, never printed.
set -euo pipefail

hdr=""
cleanup() {
    if [ -n "${hdr:-}" ] && [ -f "$hdr" ]; then
        rm -f "$hdr"
    fi
}
trap cleanup EXIT

load_key() {
    local secrets key=""
    secrets="${XDG_CONFIG_HOME:-$HOME/.config}/modern/secrets.json"
    if [ -f "$secrets" ] && command -v jq >/dev/null 2>&1; then
        key="$(jq -r '.gemini.apiKey // empty' "$secrets" 2>/dev/null || true)"
    fi
    if [ -z "$key" ]; then
        key="${GEMINI_API_KEY:-}"
    fi
    if [ -z "$key" ]; then
        echo "gemini-api: missing key" >&2
        exit 2
    fi
    hdr="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/modern-gemini.XXXXXX")"
    chmod 600 "$hdr"
    printf 'x-goog-api-key: %s\n' "$key" >"$hdr"
}

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
        load_key
        curl -sS --max-time 15 \
            -H "@${hdr}" \
            "https://generativelanguage.googleapis.com/v1beta/models"
        ;;
    chat)
        model="${2:-}"
        body="${3:-}"
        safe_model "$model"
        if [ ! -f "$body" ]; then
            echo "gemini-api: missing body" >&2
            exit 3
        fi
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # exec so Stop kills the worker, not a leftover curl pipe.
        exec python3 -u "$here/gemini-ndjson.py" chat "$model" "$body"
        ;;
    *)
        echo "Usage: gemini-api.sh models|chat MODEL BODY" >&2
        exit 1
        ;;
esac
