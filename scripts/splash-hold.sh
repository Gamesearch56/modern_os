#!/usr/bin/env bash
# Hold the boot splash across the gaps where a laptop redraws the seat
# terminal: greeter to desktop, desktop back to greeter, and power off.
# Hyprland's own banner is not a kernel message, so quiet does not hide it.
# The power menu calls this directly. The splash service is optional: a
# missing unit must not block logout, reboot, or shutdown.
#
# Every action is written to the journal (tag modern-session) so a hang
# or refusal at logout/shutdown shows up in the bug report.
set -euo pipefail

note() {
    logger -t modern-session "$*" 2>/dev/null || true
}

splash_show() {
    if plymouth --ping >/dev/null 2>&1; then
        plymouth show-splash || true
        return 0
    fi
    rm -f /run/plymouth/pid 2>/dev/null || true
    plymouthd --mode=boot --pid-file=/run/plymouth/pid --attach-to-session || true
    plymouth show-splash || true
}

ask_splash() {
    # --no-ask-password: a missing polkit grant must fail quietly. An
    # interactive prompt races the reboot and flashes a password window.
    timeout 2 systemctl start --no-ask-password modern-splash.service \
        || note "splash service did not start before $1 (exit $?)"
}

case "${1:-show}" in
    show)
        splash_show
        ;;
    logout)
        # Plymouth has to be waiting before this compositor dies, or the
        # laptop paints the terminal in the gap.
        note "logout requested by $(id -un)"
        ask_splash logout
        hyprctl dispatch 'hl.dsp.exit()' || {
            rc=$?
            note "logout failed: hyprctl exit $rc"
            exit "$rc"
        }
        ;;
    reboot|poweroff)
        note "$1 requested by $(id -un)"
        ask_splash "$1"
        # An inhibitor or a polkit refusal leaves the desktop running;
        # say so instead of failing silently from the power menu.
        systemctl "$1" || {
            rc=$?
            note "$1 refused: systemctl exit $rc"
            exit "$rc"
        }
        ;;
    *)
        printf 'splash-hold: use show, logout, reboot, or poweroff\n' >&2
        exit 1
        ;;
esac
