#!/usr/bin/env bash
# Live ISO: greetd starts a kiosk compositor whose only client is
# Calamares. Hyprland Lua autostart never reliably opened the installer
# (hl.exec_cmd races / emergency mode / root seat). cage is what greetd
# documents for a single fullscreen app. pixman so QEMU still paints
# when virtio-gl is flaky.
set -euo pipefail

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export WLR_RENDERER="${WLR_RENDERER:-pixman}"
export WLR_NO_HARDWARE_CURSORS="${WLR_NO_HARDWARE_CURSORS:-1}"

log() {
    printf '%s\n' "$*" >>/tmp/live-session.log 2>/dev/null || true
    if [ -w /dev/ttyS0 ]; then
        printf '%s\n' "$*" >/dev/ttyS0 || true
    fi
}

log "live-session uid=$(id -u) HOME=${HOME:-} RUNTIME=${XDG_RUNTIME_DIR:-} cage=$(command -v cage || true)"

if ! command -v cage >/dev/null 2>&1; then
    log "cage missing"
    exit 1
fi

if command -v dbus-run-session >/dev/null 2>&1 \
    && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    log "exec dbus-run-session -- cage -s -- live-calamares.sh"
    exec dbus-run-session -- cage -s -- /usr/lib/modern/live-calamares.sh
fi
log "exec cage -s -- /usr/lib/modern/live-calamares.sh"
exec cage -s -- /usr/lib/modern/live-calamares.sh
