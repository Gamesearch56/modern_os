#!/usr/bin/env bash
# Hold the boot splash across the gaps where a laptop redraws the seat
# terminal: greeter to desktop, desktop back to greeter, and power off.
# Hyprland's own banner is not a kernel message, so quiet does not hide it.
# The power menu calls this directly. The splash service is optional: a
# missing unit must not block logout, reboot, or shutdown.
set -euo pipefail

splash_show() {
    if plymouth --ping >/dev/null 2>&1; then
        plymouth show-splash || true
        return 0
    fi
    rm -f /run/plymouth/pid
    plymouthd --mode=boot --pid-file=/run/plymouth/pid --attach-to-session || true
    plymouth show-splash || true
}

ask_splash() {
    timeout 2 systemctl start modern-splash.service || true
}

case "${1:-show}" in
    show)
        splash_show
        ;;
    logout)
        # Plymouth has to be waiting before this compositor dies, or the
        # laptop paints the terminal in the gap.
        ask_splash
        exec hyprctl dispatch 'hl.dsp.exit()'
        ;;
    reboot|poweroff)
        ask_splash
        exec systemctl "$1"
        ;;
    *)
        printf 'splash-hold: use show, logout, reboot, or poweroff\n' >&2
        exit 1
        ;;
esac
