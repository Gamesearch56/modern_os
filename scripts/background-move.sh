#!/usr/bin/env bash
# Move one window onto special:background and leave that workspace closed.
# toggle_special creates it by showing it. The second toggle on the same
# monitor closes the empty workspace. Once windows are on it, toggling
# from the other monitor moves the workspace and drops those windows onto
# workspace 1. Focusing the numbered workspace underneath closes the view.
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

flip() {
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("background")' >/dev/null
}

monitors="$(hyprctl monitors -j)"
exists="$(hyprctl workspaces -j | jq -r '[.[] | select(.name == "special:background")] | length')"
open_on="$(printf '%s' "$monitors" | jq -r 'first(.[] | select((.specialWorkspace.name // "") == "special:background") | .name) // empty')"
prev_id="$(printf '%s' "$monitors" | jq -r 'first(.[] | select(.focused == true) | .activeWorkspace.id) // empty')"

if [[ "${exists:-0}" == "0" ]]; then
    flip
    flip
    open_on=""
fi

if [[ -n "$open_on" ]]; then
    target="$(printf '%s' "$monitors" | jq -r --arg n "$open_on" 'first(.[] | select(.name == $n) | .activeWorkspace.id) // empty')"
    if [[ -n "$target" ]]; then
        hyprctl dispatch "hl.dsp.focus({ workspace = ${target} })" >/dev/null
    fi
    still="$(hyprctl monitors -j | jq -r 'first(.[] | select((.specialWorkspace.name // "") == "special:background") | .name) // empty')"
    focused_now="$(hyprctl monitors -j | jq -r 'first(.[] | select(.focused == true) | .name) // empty')"
    if [[ -n "$still" && "$focused_now" == "$still" ]]; then
        flip
    fi
    if [[ -n "$prev_id" && "$prev_id" != "$target" && "$prev_id" != "null" ]]; then
        hyprctl dispatch "hl.dsp.focus({ workspace = ${prev_id} })" >/dev/null
    fi
fi

window_fade_out "$addr"
hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:background\", follow = false, window = \"address:${addr}\" })" >/dev/null
window_fade_finish "$addr"
