#!/usr/bin/env bash
# Live ISO: greetd starts a kiosk compositor whose only client is
# Calamares. Hyprland Lua autostart never reliably opened the installer
# (hl.exec_cmd races / emergency mode / root seat). cage is what greetd
# documents for a single fullscreen app. pixman only in VMs so a real
# machine is not stuck on a software renderer until Calamares maps.
set -euo pipefail

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland

if [ -z "${WLR_RENDERER:-}" ] \
    && command -v systemd-detect-virt >/dev/null 2>&1 \
    && systemd-detect-virt -q; then
    export WLR_RENDERER=pixman
    export WLR_NO_HARDWARE_CURSORS="${WLR_NO_HARDWARE_CURSORS:-1}"
fi

log() {
    printf '%s\n' "$*" >>/tmp/live-session.log 2>/dev/null || true
    if [ -w /dev/ttyS0 ]; then
        printf '%s\n' "$*" >/dev/ttyS0 || true
    fi
}

log "live-session uid=$(id -u) HOME=${HOME:-} RUNTIME=${XDG_RUNTIME_DIR:-} cage=$(command -v cage || true) renderer=${WLR_RENDERER:-auto}"

# Cage's own keymap is what Xwayland types with. The helper replaces
# that map when the installer writes a layout. Xwayland and Calamares
# drop the preload themselves.
if [ -f /usr/lib/modern/live-xkb-cage.so ]; then
    export LD_PRELOAD="/usr/lib/modern/live-xkb-cage.so${LD_PRELOAD:+:$LD_PRELOAD}"
    # The helper also runs setxkbmap. Xwayland keeps its own map when it
    # ignores a later keymap event from cage, which is the first selection.
    export MODERN_XKB_PUSH_X=1
    log "keyboard helper preloaded"
fi

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
