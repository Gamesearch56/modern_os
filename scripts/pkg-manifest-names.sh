#!/usr/bin/env bash
# Package names this desktop ships (install/manifests). App Store uses
# this so leftover packages from another session are not "system".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/install/manifests"

names="$(
    find "$DIR" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.aur.txt' \) -print0 \
        | sort -z \
        | xargs -0 -I{} sed -E 's/#.*$//' {} \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/\r$//' \
        | grep -v '^$' \
        | grep -E '^[a-z0-9][a-z0-9.+_-]*$' \
        | sort -u
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
