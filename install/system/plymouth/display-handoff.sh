#!/usr/bin/env bash
# Sourced by the login and desktop launchers. Also safe to run directly.
# shellcheck shell=bash

# The next compositor must not attach to one that is exiting, and an
# eDP panel must not be power-cycled. That cycle is when the panel
# paints the firmware logo stored in it.
display_handoff_prepare() {
    unset WAYLAND_DISPLAY
    unset DISPLAY
    if [ -w /dev/fb0 ]; then
        # The console framebuffer still holds the firmware logo. A gap
        # that shows the console would put that logo on the panel.
        dd if=/dev/zero of=/dev/fb0 bs=1M count=16 status=none conv=notrunc || true
    fi
    if [ ! -d /sys/module/i915 ]; then
        return 0
    fi
    local match f
    match="$(echo /sys/class/drm/card*-eDP-*)"
    case "$match" in
        '/sys/class/drm/card*-eDP-*' | "") return 0 ;;
    esac
    for f in /var/lib/modern/session/monitors.json \
        "${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"; do
        [ -r "$f" ] || continue
        # Variable refresh needs atomic commits. Keep those, and accept
        # the longer handoff, when a profile asked for it.
        if grep -q '"vrr"[[:space:]]*:[[:space:]]*true' "$f"; then
            return 0
        fi
    done
    # A leftover page-flip makes the atomic path modeset. On eDP that
    # turns the panel off for the power-cycle delay, and the panel
    # draws its firmware logo until the link is back. The legacy path
    # programs the mode that is already active.
    export AQ_NO_ATOMIC=1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    display_handoff_prepare
fi
