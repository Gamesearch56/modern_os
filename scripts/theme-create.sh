#!/usr/bin/env bash
# Write a theme profile JSON. SLUG must be [a-z0-9-]+. BODY is the JSON
# document. Optional DIR defaults to ~/.config/modern/themes; derived
# profiles from Settings use $XDG_STATE_HOME/modern/themes.
set -euo pipefail

slug="${1:-}"
body="${2:-}"
if [[ ! "$slug" =~ ^[a-z0-9-]+$ ]]; then
    echo "theme-create: invalid slug" >&2
    exit 2
fi
if [ -z "$body" ]; then
    echo "theme-create: empty body" >&2
    exit 2
fi
if ! printf '%s' "$body" | jq -e . >/dev/null; then
    echo "theme-create: body is not JSON" >&2
    exit 2
fi

dir="${3:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/themes}"
mkdir -p "$dir"
out="$dir/${slug}.json"
printf '%s\n' "$body" >"$out"
echo "$out"
