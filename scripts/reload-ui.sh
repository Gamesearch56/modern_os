#!/usr/bin/env bash
# Reload compositor UI without regenerating the theme.
# Hyprland Lua, hypridle, Quickshell, kitty colors, polkit agent.
# Quickshell-only: `modern shell reload`.
set -euo pipefail

USER_NAME="${USER:-$(id -un)}"

# Hyprland 0.56 Lua dispatchers reject `hyprctl dispatch exec`. Spawn
# in this session instead. qs is a Hyprland child from hyprland.start
# and dies with the compositor; reload does not re-run that callback.
start_quickshell() {
    local log="${XDG_STATE_HOME:-$HOME/.local/state}/modern/quickshell.log"
    mkdir -p "$(dirname "$log")"
    nohup env QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}" \
        QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}" \
        QS_ICON_THEME="${QS_ICON_THEME:-Papirus-Dark}" \
        qs -c modern >>"$log" 2>&1 &
    disown $! 2>/dev/null || true
}

if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || echo "reload-ui: hyprctl reload failed" >&2
    if [ -d "/var/cache/hyprpm/${USER_NAME}" ] && command -v hyprpm >/dev/null 2>&1; then
        hyprpm reload -n >/dev/null 2>&1 || true
    fi
    if pgrep -u "$USER_NAME" -x hypridle >/dev/null 2>&1; then
        pkill -u "$USER_NAME" -x hypridle || true
        nohup hypridle >/dev/null 2>&1 &
        disown $! 2>/dev/null || true
    fi
    # shellcheck source=lib/polkit-agent.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/polkit-agent.sh"
    ensure_polkit_agent || true
fi

if command -v qs >/dev/null 2>&1; then
    if ! qs -c modern ipc call shell reload >/dev/null 2>&1; then
        if ! pgrep -u "$USER_NAME" -x qs >/dev/null 2>&1 \
            && ! pgrep -u "$USER_NAME" -x quickshell >/dev/null 2>&1; then
            start_quickshell
            for _ in $(seq 1 25); do
                qs -c modern ipc call shell reload >/dev/null 2>&1 && break
                sleep 0.2
            done
        fi
        qs -c modern ipc call shell reload >/dev/null 2>&1 \
            || echo "reload-ui: Quickshell IPC reload failed" >&2
    fi
fi

if command -v kitty >/dev/null 2>&1; then
    kitty @ load-config >/dev/null 2>&1 || true
fi
