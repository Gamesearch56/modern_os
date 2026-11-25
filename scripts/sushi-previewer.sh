#!/usr/bin/env bash
# GNOME Sushi with G_RESOURCE_OVERLAYS: media starts muted (volume 0).
# Selection follow is Nautilus-native; Hyprland must not stay_focused.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$SCRIPT_DIR/lib/sushi-overlay"
PREVIEWER=/usr/lib/org.gnome.NautilusPreviewer

if [ -d "$OVERLAY" ]; then
    export G_RESOURCE_OVERLAYS="/org/gnome/NautilusPreviewer/js=${OVERLAY}${G_RESOURCE_OVERLAYS:+:${G_RESOURCE_OVERLAYS}}"
fi

exec "$PREVIEWER" "$@"
