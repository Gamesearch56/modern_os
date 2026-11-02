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

scan=0
[ "${1:-}" = --scan ] && scan=1

if ! grep -q '^wl ' /proc/modules 2>/dev/null; then
    /usr/lib/modern/live-wifi-wl.sh >/dev/null 2>&1 || true
fi
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

# A network controller with no interface under it has no driver.
chip_without_driver() {
    local dev class
    for dev in "$SYS_PCI"/*; do
        [ -e "$dev/class" ] || continue
        class="$(tr -d '[:space:]' <"$dev/class")"
        case "$class" in
            0x0280*) ;;
            *) continue ;;
        esac
        [ -d "$dev/net" ] && continue
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
