#!/usr/bin/env bash
# Search official sync DBs (pacman -Ss). JSON array, cap 50.
# Usage: pkg-search.sh QUERY [CURATED_NAME...]
# Curated names (Store catalog hits for QUERY, e.g. "photo" -> gimp) come
# first via pkg-info.sh; pacman -Ss matches follow without duplicates.
# No -Sy — refresh stays with Settings → System.
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
CURATED="$curated" python3 -c '
import json, os, re, sys
try:
    rows = json.loads(os.environ.get("CURATED") or "[]")
except ValueError:
    rows = []
seen = {r.get("name") for r in rows}
text = sys.stdin.read()
pat = re.compile(r"^([a-z0-9-]+)/([a-z0-9][a-z0-9.+_-]*)\s+(\S+)(.*)$")
lines = text.splitlines()
i = 0
while i < len(lines) and len(rows) < 50:
    m = pat.match(lines[i])
    if not m:
        i += 1
        continue
    repo, name, version, rest = m.group(1), m.group(2), m.group(3), m.group(4)
    desc = ""
    if i + 1 < len(lines) and lines[i + 1].startswith("    "):
        desc = lines[i + 1].strip()
        i += 2
    else:
        i += 1
    if name in seen:
        continue
    seen.add(name)
    rows.append({
        "name": name,
        "repo": repo,
        "version": version,
        "desc": desc,
        "installed": "[installed]" in rest,
    })
print(json.dumps(rows, ensure_ascii=False))
' < <(LC_ALL=C "$PACMAN" -Ss -- "$query" 2>/dev/null || true)
