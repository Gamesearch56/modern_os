#!/usr/bin/env bash
# Search official sync DBs (pacman -Ss). JSON array, cap 50.
# Usage: pkg-search.sh QUERY [CURATED_NAME...]
# Curated names (Store catalog hits for QUERY, e.g. "photo" -> gimp) come
# first via pkg-info.sh. Pacman hits follow only when the query is in the
# package name, or is a whole word in the description — "oll" matches
# ollama and does not match "collection". No -Sy — refresh stays with
# Settings → System.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

query="$(printf '%s' "${1:-}" | tr -d '\n' | head -c 80)"
if [ -z "$query" ] || [[ "$query" == -* ]]; then
    printf '%s\n' '[]'
    exit 0
fi
shift

curated='[]'
if [ "$#" -gt 0 ]; then
    curated="$("$ROOT/pkg-info.sh" "$@" 2>/dev/null || printf '[]')"
fi

PACMAN="/usr/bin/pacman"
needle="$(python3 -c 'import re,sys; print(re.escape(sys.argv[1]))' "$query")"
CURATED="$curated" python3 "$ROOT/lib/pkg_search.py" --query "$query" --limit 50 --curated-env \
    < <(LC_ALL=C "$PACMAN" -Ss -- "$needle" 2>/dev/null || true)
