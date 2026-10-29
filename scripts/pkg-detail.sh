#!/usr/bin/env bash
# One-package pacman -Si as JSON (url, licenses, depends, size).
# Usage: pkg-detail.sh NAME
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"

name="${1:-}"
if [ "$#" -ne 1 ] || ! valid_pkg_name "$name"; then
    printf '%s\n' '{}'
    exit 2
fi

PACMAN="/usr/bin/pacman"
info="$(LC_ALL=C "$PACMAN" -Si -- "$name" 2>/dev/null || true)"
if [ -z "$info" ]; then
    printf '%s\n' '{}'
    exit 3
fi
have=0
LC_ALL=C "$PACMAN" -Q -- "$name" >/dev/null 2>&1 && have=1
localver=""
if [ "$have" -eq 1 ]; then
    localver="$(LC_ALL=C "$PACMAN" -Q -- "$name" 2>/dev/null | awk '{print $2}')"
fi

HAVE="$have" LOCALVER="$localver" python3 -c '
import json, os, sys

def split_list(val):
    val = (val or "").strip()
    if not val or val == "None":
        return []
    return [p for p in val.split() if p and p != "None"]

text = sys.stdin.read()
cur = {}
key = ""
for line in text.splitlines():
    if not line.strip():
        continue
    if line.startswith(" ") and key:
        cur[key] = (cur.get(key) or "") + " " + line.strip()
        continue
    if ":" not in line:
        continue
    k, _, val = line.partition(":")
    key = k.strip().lower()
    cur[key] = val.strip()

name = cur.get("name") or ""
row = {
    "name": name,
    "repo": cur.get("repository") or "",
    "version": cur.get("version") or "",
    "desc": cur.get("description") or "",
    "url": cur.get("url") or "",
    "licenses": cur.get("licenses") or "",
    "groups": cur.get("groups") or "",
    "depends": split_list(cur.get("depends on")),
    "optdepends": [p for p in (cur.get("optional deps") or "").split("  ") if p.strip() and p.strip() != "None"],
    "isize": cur.get("installed size") or "",
    "packager": cur.get("packager") or "",
    "builddate": cur.get("build date") or "",
    "installed": os.environ.get("HAVE") == "1",
    "localVersion": os.environ.get("LOCALVER") or "",
}
print(json.dumps(row, ensure_ascii=False))
' <<<"$info"
