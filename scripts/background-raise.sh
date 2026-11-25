#!/usr/bin/env bash
# Bring one window from special:background onto a workspace and focus it,
# fading in place. Usage: background-raise.sh <address> [workspace-id]
# Without an id the focused monitor's active workspace is used.
set -euo pipefail

# shellcheck source=lib/window-fade.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/window-fade.sh"

addr="${1:-}"
addr="${addr#address:}"
if [[ -z "$addr" || "$addr" == "null" ]]; then
    exit 1
fi
if [[ "$addr" != 0x* && "$addr" != 0X* ]]; then
    addr="0x${addr}"
fi

ws="${2:-}"
if [[ -z "$ws" ]]; then
    ws="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // empty')"
fi
if [[ -z "$ws" || "$ws" == "null" || "$ws" -le 0 ]]; then
    exit 1
fi

window_fade_prepare_in "$addr"
hyprctl dispatch "hl.dsp.window.move({ workspace = ${ws}, follow = true, window = \"address:${addr}\" })" >/dev/null
hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })" >/dev/null
window_fade_finish "$addr"
