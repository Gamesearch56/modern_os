#!/usr/bin/env bash
# List ~/.config/modern/plugins/*/plugin.json as JSON lines with `dir`.
set -euo pipefail

dir="${XDG_CONFIG_HOME:-$HOME/.config}/modern/plugins"
[ -d "$dir" ] || exit 0

shopt -s nullglob
for f in "$dir"/*/plugin.json; do
    [ -f "$f" ] || continue
    d="$(dirname "$f")"
    if command -v jq >/dev/null 2>&1; then
        jq -c --arg d "$d" '. + {dir:$d}' "$f"
    else
        printf '{"dir":"%s"}\n' "$d"
    fi
done
