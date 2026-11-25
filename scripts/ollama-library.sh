#!/usr/bin/env bash
# Search the Ollama library, list one family's sizes, or pull/remove.
# Usage: ollama-library.sh search [QUERY]
#        ollama-library.sh tags FAMILY
#        ollama-library.sh pull NAME
#        ollama-library.sh remove NAME
# An empty search reads the whole library. tags lists every plain size.
# pull and remove take one checked name and run ollama directly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$ROOT/lib/ollama_library.py"

usage() {
    printf 'usage: ollama-library.sh search [QUERY] | tags FAMILY | pull NAME | remove NAME\n' >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 2
fi

cmd="$1"
case "$cmd" in
    search | tags | pull | remove) ;;
    *)
        usage
        exit 2
        ;;
esac

fetch_html() {
    local url="$1" dest="$2"
    case "$url" in
        https://ollama.com/search\?q=* | https://ollama.com/library\?sort=popular | https://ollama.com/library/*/tags) ;;
        *) return 1 ;;
    esac
    curl --proto '=https' --tlsv1.2 -fsS --max-time 20 \
        -A 'modern-settings' -o "$dest" --url "$url"
}

if [ "$cmd" = "search" ]; then
    query="$(printf '%s' "${2:-}" | tr -d '\n' | head -c 60)"
    if [ -z "$query" ] && [ "${OLLAMA_LIBRARY_OFFLINE:-}" = "1" ]; then
        python3 "$PY" search --query ""
        exit 0
    fi
    if [ -z "$query" ] && [ -n "${OLLAMA_LIBRARY_INDEX_HTML:-}" ]; then
        python3 "$PY" search --query "" --html "$OLLAMA_LIBRARY_INDEX_HTML"
        exit 0
    fi
    if [ -n "$query" ] && [ -n "${OLLAMA_LIBRARY_SEARCH_HTML:-}" ]; then
        python3 "$PY" search --query "$query" --html "$OLLAMA_LIBRARY_SEARCH_HTML"
        exit 0
    fi
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/modern-ollama-lib-XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    if [ -z "$query" ]; then
        url="$(python3 "$PY" index-url)"
    else
        url="$(python3 "$PY" url --query "$query")"
    fi
    if ! fetch_html "$url" "$tmp/search.html"; then
        if [ -z "$query" ]; then
            python3 "$PY" search --query ""
            exit 0
        fi
        printf '[]\n'
        exit 1
    fi
    python3 "$PY" search --query "$query" --html "$tmp/search.html"
    exit 0
fi

if [ "$cmd" = "tags" ]; then
    family="$(python3 "$PY" check --name "${2:-}")" || {
        printf '[]\n'
        exit 2
    }
    family="${family%%:*}"
    if [ -n "${OLLAMA_LIBRARY_TAGS_DIR:-}" ]; then
        python3 "$PY" tags --name "$family" --html "$OLLAMA_LIBRARY_TAGS_DIR/${family//\//__}.html"
        exit 0
    fi
    url="$(python3 "$PY" tags-url --name "$family")"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/modern-ollama-tags-XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    if ! fetch_html "$url" "$tmp/tags.html"; then
        printf '[]\n'
        exit 1
    fi
    python3 "$PY" tags --name "$family" --html "$tmp/tags.html"
    exit 0
fi

name="$(python3 "$PY" check --name "${2:-}")" || {
    printf 'ollama-library: invalid name\n' >&2
    exit 2
}
if [ "${OLLAMA_LIBRARY_DRY:-}" = "1" ]; then
    printf '%s %s\n' "$cmd" "$name"
    exit 0
fi

# shellcheck source=lib/ollama-quiet.sh
source "$ROOT/lib/ollama-quiet.sh"
OLLAMA="${MODERN_OLLAMA_BIN:-ollama}"
CURL="${MODERN_OLLAMA_CURL:-curl}"
if ! "$CURL" -sf --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null; then
    printf 'ollama-library: service is not answering\n' >&2
    exit 1
fi
if [ "$cmd" = "pull" ]; then
    # Status is drawn on stderr with cursor codes. A pipe sees no plain
    # lines unless those redraws are turned into newlines first.
    ollama_quiet_pull "$OLLAMA" "$name" "$ROOT/lib/ollama_progress.py"
    exit $?
fi
exec "$OLLAMA" rm "$name"
