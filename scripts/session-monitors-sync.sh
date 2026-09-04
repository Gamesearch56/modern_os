#!/usr/bin/env bash
# Snapshot monitors.profiles into the greeter session dir so the kiosk
# Hyprland can apply the same HDR/cm as the desktop (never connector names).
set -euo pipefail

SHARED="${MODERN_SESSION_DIR:-/var/lib/modern/session}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
[ -d "$SHARED" ] || exit 0
[ -f "$CFG" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tmp="$(mktemp --suffix=.json -p "$SHARED" tmp.XXXXXX)"
if jq '{profiles: (.monitors.profiles // {})}' "$CFG" >"$tmp"; then
    chmod a+r "$tmp" || true
    mv -f "$tmp" "$SHARED/monitors.json"
else
    rm -f "$tmp"
    exit 1
fi
