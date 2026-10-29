#!/usr/bin/env bash
# Next page of official-repo search hits. JSON array.
# Usage: pkg-browse.sh QUERY LIMIT [SEEN_NAME...]
# QUERY is one pacman -Ss needle (category keyword or user search).
# SEEN names are skipped so category curated rows and earlier pages
# do not repeat. No -Sy — refresh stays with Settings → System.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"

query="$(printf '%s' "${1:-}" | tr -d '\n' | head -c 80)"
limit="${2:-24}"
if [ -z "$query" ] || [[ "$query" == -* ]] || [[ ! "$limit" =~ ^[0-9]+$ ]]; then
    printf '%s\n' '[]'
    exit 0
fi
[ "$limit" -gt 0 ] || limit=1
[ "$limit" -le 48 ] || limit=48
shift 2

mapfile -t seen_names < <(filter_pkg_names "$@")
PACMAN="/usr/bin/pacman"
LIMIT="$limit" SEEN="$(printf '%s\n' "${seen_names[@]+"${seen_names[@]}"}")" python3 -c '
import json, os, re, sys
limit = int(os.environ.get("LIMIT") or "24")
seen = {n for n in os.environ.get("SEEN", "").splitlines() if n.strip()}
text = sys.stdin.read()
pat = re.compile(r"^([a-z0-9-]+)/([a-z0-9][a-z0-9.+_-]*)\s+(\S+)(.*)$")
rows = []
lines = text.splitlines()
i = 0
while i < len(lines) and len(rows) < limit:
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
