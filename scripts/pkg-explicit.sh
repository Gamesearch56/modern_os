#!/usr/bin/env bash
# Explicitly installed package names (pacman -Qqe). JSON string array.
set -euo pipefail

PACMAN="/usr/bin/pacman"
names="$(LC_ALL=C "$PACMAN" -Qqe 2>/dev/null || true)"
printf '%s\n' "$names" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()][:150], ensure_ascii=False))'
