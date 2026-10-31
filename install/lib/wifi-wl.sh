#!/usr/bin/env bash
# Broadcom PCI wifi that needs the proprietary wl driver. b43 parts need
# firmware nothing here ships; the rest have no open driver. brcmsmac
# (4313, 43224/43225) and brcmfmac chips are not listed.
# Source, never execute. WIFI_PCI_ROOT overrides /sys for tests.

wifi_needs_wl() {
    local root dev vendor device class
    root="${WIFI_PCI_ROOT:-/sys/bus/pci/devices}"
    [ -d "$root" ] || return 1
    for dev in "$root"/*; do
        [ -e "$dev/vendor" ] || continue
        vendor="$(tr -d '[:space:]' <"$dev/vendor")"
        device="$(tr -d '[:space:]' <"$dev/device")"
        class="$(tr -d '[:space:]' <"$dev/class")"
        [ "$vendor" = 0x14e4 ] || continue
        case "$class" in
            0x0280*) ;;
            *) continue ;;
        esac
        case "$device" in
            0x4311|0x4312|0x4315|0x4328|0x432b|0x4331|0x4358|0x4359|0x43a0|0x43b1)
                return 0
                ;;
        esac
    done
    return 1
}
