#!/usr/bin/env bash
# Package names this desktop ships (install/manifests). Update uses the
# full list so leftover packages from another session are not "system".
# --core: only the layers the desktop cannot run without (base, hardware,
# desktop, theming) — Store's undeletable "system" list. Apps and gaming
# layers stay removable there.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/install/manifests"
# shellcheck source=../install/lib/default-apps.sh
source "$ROOT/install/lib/default-apps.sh"

files=()
if [ "${1:-}" = "--core" ]; then
    for f in "$DIR"/00-*.txt "$DIR"/10-*.txt "$DIR"/20-*.txt; do
        [ -f "$f" ] && files+=("$f")
    done
else
    for f in "$DIR"/*.txt; do
        [ -f "$f" ] && files+=("$f")
    done
fi

names="$(
    {
        if [ ${#files[@]} -gt 0 ]; then
            sed -E 's/#.*$//' "${files[@]}"
        fi
        default_app_packages
    } \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/\r$//' \
        | grep -E '^[a-z0-9][a-z0-9.+_-]*$' \
        | sort -u || true
)"
printf '%s\n' "$names" | python3 -c '
import json, sys
names = [l.strip() for l in sys.stdin if l.strip()]
out = set(names)
for n in names:
    if n.endswith("-bin"):
        out.add(n[: -len("-bin")])
print(json.dumps(sorted(out), ensure_ascii=False))
'
