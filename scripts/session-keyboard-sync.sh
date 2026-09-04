#!/usr/bin/env bash
# Snapshot input.kbLayout / kbVariant for the greetd kiosk Hyprland.
# Settings and Calamares both write config.json; the greeter must not
# keep a leftover us layout from the stock kiosk lua.
set -euo pipefail

SHARED="${MODERN_SESSION_DIR:-/var/lib/modern/session}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
[ -d "$SHARED" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

layout=""
variant=""
if [ -f "$CFG" ]; then
    layout="$(jq -r '.input.kbLayout // empty' "$CFG" 2>/dev/null || true)"
    variant="$(jq -r '.input.kbVariant // empty' "$CFG" 2>/dev/null || true)"
fi
layout="$(printf '%s' "$layout" | tr -cd 'a-z0-9,_-')"
variant="$(printf '%s' "$variant" | tr -cd 'a-z0-9,_-')"
[ -n "$layout" ] || layout="us"

tmp="$(mktemp --suffix=.json -p "$SHARED" tmp.XXXXXX)"
if jq -n --arg l "$layout" --arg v "$variant" '{layout:$l, variant:$v}' >"$tmp"; then
    chmod a+r "$tmp" || true
    mv -f "$tmp" "$SHARED/keyboard.json"
else
    rm -f "$tmp"
    exit 1
fi
