#!/usr/bin/env bash
# Live ISO: Calamares is root on Xwayland. Firefox refuses root, so drop
# to liveuser on the same DISPLAY. Do not pass WAYLAND_DISPLAY — cage
# only accepts Xwayland as its client.
set -euo pipefail

open() {
    exec /usr/bin/xdg-open "$@"
}

if [ "$(id -u)" -eq 0 ] && id liveuser >/dev/null 2>&1; then
    live_uid="$(id -u liveuser)"
    exec runuser -u liveuser -- env -u WAYLAND_DISPLAY \
        HOME=/home/liveuser \
        DISPLAY="${DISPLAY:-:0}" \
        XDG_RUNTIME_DIR="/run/user/${live_uid}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${live_uid}/bus" \
        /usr/bin/xdg-open "$@"
fi
open "$@"
