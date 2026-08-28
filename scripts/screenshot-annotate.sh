#!/usr/bin/env bash
# Capture a screenshot then open it in swappy for annotation when that
# editor is installed. Falls back to grim-only so a missing swappy never
# loses the shot.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { printf 'screenshot-annotate: missing %s\n' "$1" >&2; exit 1; }; }
need grim

dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="${dir}/screenshot-$(date +%Y%m%d-%H%M%S).png"

if command -v slurp >/dev/null 2>&1; then
    geom="$(slurp)" || exit 1
    grim -g "$geom" "$file"
else
    grim "$file"
fi

if command -v swappy >/dev/null 2>&1; then
    swappy -f "$file"
else
    printf 'screenshot-annotate: swappy not on PATH — saved %s\n' "$file" >&2
fi
printf '%s\n' "$file"
