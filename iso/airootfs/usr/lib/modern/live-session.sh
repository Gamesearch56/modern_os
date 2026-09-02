#!/usr/bin/env bash
# Live ISO: greetd (or a root TTY fallback) starts the compositor here.
# start-hyprland owns the session; hyprland.lua is the only config format.
set -euo pipefail

CONF=/etc/modern/live-hyprland.lua
export QT_QPA_PLATFORM=wayland
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland

cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
mkdir -p "$cfg_dir"
ln -sfn "$CONF" "$cfg_dir/hyprland.lua"

args=()
if [ "$(id -u)" -eq 0 ]; then
    args+=(--i-am-really-stupid)
fi

if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland "${args[@]}"
fi
exec Hyprland "${args[@]}" --config "$CONF"
