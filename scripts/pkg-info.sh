#!/usr/bin/env bash
# Batch pacman -Si / installed check. JSON array, argv names only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"

mapfile -t names < <(filter_pkg_names "$@")
if [ "${#names[@]}" -eq 0 ]; then
    printf '%s\n' '[]'
    exit 0
fi

PACMAN="${PACMAN:-/usr/bin/pacman}"
info="$(LC_ALL=C "$PACMAN" -Si -- "${names[@]}" 2>/dev/null || true)"
installed="$(LC_ALL=C "$PACMAN" -Qq -- "${names[@]}" 2>/dev/null || true)"

INSTALLED="$installed" python3 -c '
import json, os, sys
text = sys.stdin.read()
have = {n for n in os.environ.get("INSTALLED", "").splitlines() if n.strip()}
rows = []
cur = {}
pending_repo = ""

def flush():
    global cur
    name = cur.get("name") or ""
    if name:
        rows.append({
            "name": name,
            "repo": cur.get("repo") or "",
            "version": cur.get("version") or "",
            "desc": cur.get("desc") or "",
            "installed": name in have,
        })
    cur = {}

for line in text.splitlines():
    if not line.strip():
        flush()
        continue
    if ":" not in line:
        continue
    key, _, val = line.partition(":")
    key = key.strip().lower()
    val = val.strip()
    if key == "repository":
        pending_repo = val
        cur["repo"] = val
    elif key == "name":
        flush()
        cur = {"name": val, "repo": pending_repo}
    elif key == "version":
        cur["version"] = val
    elif key == "description":
        cur["desc"] = val
flush()
print(json.dumps(rows, ensure_ascii=False))
' <<<"$info"
