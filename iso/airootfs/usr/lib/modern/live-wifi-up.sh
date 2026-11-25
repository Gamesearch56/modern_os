#!/usr/bin/env bash
# Hands every radio to NetworkManager and records what is in the way.
# live-setup.sh runs it at boot; the installer's Network step runs it
# again on Refresh (--scan), because a radio can appear after boot
# (firmware, a USB stick) or be soft-blocked by a hotkey. One line in
# /run/modern/wifi-state:
#   ok | off | blocked | nodriver <vendor:device> | none
# Best effort: no step may stop the next one.
set -uo pipefail

STATE_DIR="${WIFI_STATE_DIR:-/run/modern}"
STATE="$STATE_DIR/wifi-state"
SYS_NET="${WIFI_SYS_NET:-/sys/class/net}"
SYS_PCI="${WIFI_PCI_ROOT:-/sys/bus/pci/devices}"
MODPROBE_D="${WIFI_MODPROBE_D:-/etc/modprobe.d}"
RTW88_CONF="$MODPROBE_D/modern-rtw88.conf"

scan=0
[ "${1:-}" = --scan ] && scan=1

# A network controller with no interface under it has no working driver.
driverless() {
    local class
    [ -e "$1/class" ] || return 1
    class="$(tr -d '[:space:]' <"$1/class")"
    case "$class" in
        0x0280*) ;;
        *) return 1 ;;
    esac
    [ ! -d "$1/net" ]
}

# rtw88 (RTL8821CE, RTL8822CE, ...) fails its probe on many laptops with
# PCIe ASPM or MSI on, and leaves no interface. The same driver with both
# off comes up. calamares-late.sh carries the option to the target when
# this had to set it.
revive_driverless() {
    local dev mod
    for dev in "$SYS_PCI"/*; do
        driverless "$dev" || continue
        [ -r "$dev/modalias" ] || continue
        mod="$(modprobe -R "$(cat "$dev/modalias")" 2>/dev/null | head -n 1)"
        [ -n "$mod" ] || continue
        modprobe "$mod" >/dev/null 2>&1 || true
        command -v udevadm >/dev/null 2>&1 && udevadm settle >/dev/null 2>&1
        driverless "$dev" || continue
        case "$mod" in
            rtw88_*) ;;
            *) continue ;;
        esac
        [ -e "$RTW88_CONF" ] && continue
        mkdir -p "$MODPROBE_D" 2>/dev/null || true
        printf 'options rtw88_pci disable_aspm=y disable_msi=y\n' 2>/dev/null >"$RTW88_CONF" || continue
        modprobe -r "$mod" rtw88_pci >/dev/null 2>&1 || true
        modprobe "$mod" >/dev/null 2>&1 || true
        command -v udevadm >/dev/null 2>&1 && udevadm settle >/dev/null 2>&1
    done
    return 0
}

if ! grep -q '^wl ' /proc/modules 2>/dev/null; then
    /usr/lib/modern/live-wifi-wl.sh >/dev/null 2>&1 || true
fi
revive_driverless
# iwd is D-Bus activated: anything that asks for it starts it again,
# and it then holds the radio NetworkManager needs.
systemctl mask --now iwd.service >/dev/null 2>&1 || true
rfkill unblock wifi >/dev/null 2>&1 || true
nmcli radio wifi on >/dev/null 2>&1 || true

radios=0
for nic in "$SYS_NET"/*; do
    [ -d "$nic/wireless" ] || [ -d "$nic/phy80211" ] || continue
    radios=$((radios + 1))
    name="${nic##*/}"
    nmcli device set "$name" managed yes >/dev/null 2>&1 || true
    # A link left administratively down scans as an empty list.
    ip link set "$name" up >/dev/null 2>&1 || true
done

chip_without_driver() {
    local dev
    for dev in "$SYS_PCI"/*; do
        driverless "$dev" || continue
        printf '%s:%s\n' "$(sed 's/^0x//' "$dev/vendor")" "$(sed 's/^0x//' "$dev/device")"
        return 0
    done
    return 1
}

state=ok
if [ "$radios" -eq 0 ]; then
    if chip="$(chip_without_driver)"; then
        state="nodriver $chip"
    else
        state=none
    fi
elif rfkill -n -o TYPE,HARD list 2>/dev/null | grep -q '^wlan[[:space:]]*blocked'; then
    state=blocked
elif ! nmcli radio wifi 2>/dev/null | grep -q enabled; then
    state=off
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s\n' "$state" 2>/dev/null >"$STATE" || true

if [ "$scan" -eq 1 ] && [ "$state" = ok ]; then
    nmcli -w 20 device wifi list --rescan yes >/dev/null 2>&1 || true
fi
printf '%s\n' "$state"
