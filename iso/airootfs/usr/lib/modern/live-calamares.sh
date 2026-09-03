#!/usr/bin/env bash
# Cage shows one Wayland client. That client must be Xwayland so a
# root X11 Calamares can map. liveuser cannot sudo onto cage's Wayland
# socket; Hyprland-as-root never painted.
set -euo pipefail

log=/tmp/live-calamares.log
note() {
    printf '%s\n' "$*" >>"$log" 2>/dev/null || true
    if [ -w /dev/ttyS0 ]; then
        printf '%s\n' "$*" >/dev/ttyS0 || true
    fi
}

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
    if command -v openbox >/dev/null 2>&1; then
        # Cage treats Xwayland as one client, so X11 windows have no
        # decorations unless a WM runs. Firefox Support/Issues needs a
        # close button; Calamares stays undecorated in openbox-rc.xml.
        openbox --config-file /etc/modern/openbox-rc.xml >>"$log" 2>&1 &
        sleep 0.2
    fi
    (
        i=0
        while [ "$i" -lt 120 ]; do
            if pgrep -x calamares >/dev/null 2>&1; then
                note "modern-ci: calamares"
                exit 0
            fi
            i=$((i + 1))
            sleep 1
        done
    ) &
    note "uid=$(id -u) DISPLAY=$display sudo calamares xcb"
    if [ -r /sys/firmware/qemu_fw_cfg/by_name/opt/org.modernos/unattended/raw ] \
        || grep -qw modern.unattended /proc/cmdline 2>/dev/null; then
        if [ "$(id -u)" -eq 0 ]; then
            mkdir -p /etc/calamares
            : >/etc/calamares/unattended
        else
            sudo -n mkdir -p /etc/calamares
            sudo -n touch /etc/calamares/unattended
        fi
        note "modern-ci: unattended"
    fi
    set +e
    if [ "$(id -u)" -eq 0 ]; then
        /usr/bin/env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb \
            /usr/bin/calamares "$@" >>"$log" 2>&1
    else
        # log is liveuser-writable; sudo only wraps calamares.
        # shellcheck disable=SC2024
        sudo -n /usr/bin/env -u WAYLAND_DISPLAY -u QT_QPA_PLATFORMTHEME \
            DISPLAY="$display" QT_QPA_PLATFORM=xcb /usr/bin/calamares "$@" >>"$log" 2>&1
    fi
    rc=$?
    set -e
    note "calamares exited $rc"
    if [ -s "$log" ] && [ -w /dev/ttyS0 ]; then
        tail -n 40 "$log" >/dev/ttyS0 || true
    fi
) &

note "exec Xwayland -noreset $display"
exec Xwayland -noreset "$display"
