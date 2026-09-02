#!/usr/bin/env bash
# Cage shows one Wayland client. That client must be Xwayland so a
# root X11 Calamares can map. liveuser cannot sudo onto cage's Wayland
# socket; Hyprland-as-root never painted.
set -euo pipefail

log=/tmp/live-calamares.log
note() { printf '%s\n' "$*" >>"$log" 2>/dev/null || true; }

display="${DISPLAY:-:0}"
n="${display#:}"
sock="/tmp/.X11-unix/X${n}"
export DISPLAY="$display"

(
    i=0
    while [ ! -S "$sock" ]; do
        i=$((i + 1))
        [ "$i" -ge 50 ] && { note "Xwayland socket missing"; exit 1; }
        sleep 0.1
    done
    xhost +SI:localuser:root >>"$log" 2>&1 || true
    if [ "$(id -u)" -eq 0 ]; then
        note "root session, exec calamares xcb"
        exec /usr/bin/env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb \
            /usr/bin/calamares "$@"
    fi
    note "uid=$(id -u) DISPLAY=$display sudo calamares xcb"
    exec sudo -n /usr/bin/env -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME \
        DISPLAY="$display" QT_QPA_PLATFORM=xcb /usr/bin/calamares "$@"
) &

note "exec Xwayland -noreset $display"
exec Xwayland -noreset "$display"
