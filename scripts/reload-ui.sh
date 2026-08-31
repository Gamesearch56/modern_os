#!/usr/bin/env bash
# Reload compositor UI without regenerating the theme.
# Hyprland Lua, hyprbars, hypridle, Quickshell, kitty colors, polkit agent.
# Quickshell-only: `modern shell reload`.
set -euo pipefail

USER_NAME="${USER:-$(id -un)}"

if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || echo "reload-ui: hyprctl reload failed" >&2
    if [ -d "/var/cache/hyprpm/${USER_NAME}" ] && command -v hyprpm >/dev/null 2>&1; then
        hyprpm reload -n >/dev/null 2>&1 || true
    fi
    if pgrep -u "$USER_NAME" -x hypridle >/dev/null 2>&1; then
        pkill -u "$USER_NAME" -x hypridle || true
        hyprctl dispatch exec hypridle >/dev/null 2>&1 || true
    fi
    systemctl --user try-restart hyprpolkitagent.service >/dev/null 2>&1 || true
fi

if command -v qs >/dev/null 2>&1; then
    qs -c modern ipc call shell reload >/dev/null 2>&1 \
        || echo "reload-ui: Quickshell IPC reload failed" >&2
fi

if command -v kitty >/dev/null 2>&1; then
    kitty @ load-config >/dev/null 2>&1 || true
fi
