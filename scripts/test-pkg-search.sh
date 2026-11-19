#!/usr/bin/env bash
# A typed store query matches names and whole words, not letters inside
# another word. "oll" finds ollama and skips "collection".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTER="$ROOT/scripts/lib/pkg_search.py"
SEARCH="$ROOT/scripts/pkg-search.sh"
BROWSE="$ROOT/scripts/pkg-browse.sh"
FETCH="$ROOT/stow/shell/.config/quickshell/modern/Services/StoreFetch.qml"
FAIL=0
err() { printf 'test-pkg-search: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pkg-search: ok %s\n' "$*"; }

sample="$(mktemp)"
trap 'rm -f "$sample"' EXIT
cat > "$sample" << 'EOF'
extra/gcc 14.2.1-1
    The GNU Compiler Collection - C and C++ frontends
extra/ollama 0.13.0-1
    Get up and running with large language models
extra/abseil-cpp 20240722.0-1
    Collection of C++ library code designed to augment the C++ standard library
extra/libollama 1-1
    Shared library
extra/gc 8.2.8-1
    A garbage collector for C and C++
EOF

names() {
    python3 -c 'import json,sys; print("\n".join(r["name"] for r in json.load(sys.stdin)))'
}

oll="$(python3 "$FILTER" --query oll --limit 50 < "$sample" | names)"
if [ "$oll" = $'ollama\nlibollama' ]; then
    ok "oll keeps ollama ahead of libollama and drops collection"
else
    err "oll names: $(printf '%s' "$oll" | tr '\n' ' ')"
fi

comp="$(python3 "$FILTER" --query compiler --limit 50 < "$sample" | names)"
if [ "$comp" = "gcc" ]; then
    ok "compiler matches the description word on gcc"
else
    err "compiler names: $(printf '%s' "$comp" | tr '\n' ' ')"
fi

if grep -F 'lib/pkg_search.py' "$SEARCH" >/dev/null \
    && grep -F -- '--strict' "$BROWSE" >/dev/null \
    && grep -F 'reset(h.query.trim(), true)' "$FETCH" >/dev/null; then
    ok "search and later pages use the name filter"
else
    err "pkg-search, pkg-browse --strict, or StoreFetch strict reset missing"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-pkg-search: all passed\n'
