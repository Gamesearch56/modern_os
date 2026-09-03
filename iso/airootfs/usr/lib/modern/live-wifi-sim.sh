#!/usr/bin/env bash
# Live ISO only, development aid. QEMU emulates no 802.11 adapter, so the
# installer's Network step can never reach its Wi-Fi branch in a VM.
# mac80211_hwsim gives the guest soft radios; the first one stays a station
# for the installer to scan with, the rest become WPA2 access points so the
# nearby list has something in it. Everything used here already ships on the
# image (kmod, NetworkManager, iwd, dnsmasq), because a guest booted for this
# has no wired network left to download with.
#
# Nothing starts this on its own: iso-qemu.sh --wifi-sim sets the QEMU fw_cfg
# key that live-setup.sh looks for, and calamares-late.sh strips the file off
# the installed disk.
set -euo pipefail

RADIOS="${MODERN_WIFI_SIM_RADIOS:-3}"
SSID_PREFIX="${MODERN_WIFI_SIM_SSID:-ModernOS-Test}"
PSK="${MODERN_WIFI_SIM_PSK:-modernwifi}"

note() { printf 'live-wifi-sim: %s\n' "$*"; }
die() {
    printf 'live-wifi-sim: ERROR: %s\n' "$*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || die "run as root"
case "$RADIOS" in
    '' | *[!0-9]*) die "MODERN_WIFI_SIM_RADIOS must be a number, got '$RADIOS'" ;;
esac
[ "$RADIOS" -ge 2 ] || die "need at least 2 radios: one station plus one AP"
[ "${#PSK}" -ge 8 ] || die "WPA2 needs a passphrase of at least 8 characters"

# Device names are whatever the kernel and NetworkManager settle on; the
# installer discovers them the same way, so neither side may assume wlan0.
wifi_devices() {
    nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
        | awk -F: '$2 == "wifi" { print $1 }' | sort
}

modprobe mac80211_hwsim "radios=$RADIOS" \
    || die "mac80211_hwsim did not load — not the live ISO kernel?"
nmcli radio wifi on >/dev/null 2>&1 || true

devs=()
for _ in $(seq 40); do
    mapfile -t devs < <(wifi_devices)
    [ "${#devs[@]}" -ge "$RADIOS" ] && break
    sleep 1
done
[ "${#devs[@]}" -ge 2 ] \
    || die "NetworkManager sees ${#devs[@]} Wi-Fi device(s) of $RADIOS radios"

station="${devs[0]}"
note "station $station, ${#devs[@]} radios"

up=0
index=0
for dev in "${devs[@]:1}"; do
    index=$((index + 1))
    ssid="$SSID_PREFIX-$index"
    name="modern-wifi-sim-$index"
    nmcli connection delete "$name" >/dev/null 2>&1 || true
    # ipv4.method shared puts a dnsmasq behind the AP, so the station side
    # gets a lease and a default route — which is the Next gate the Network
    # step actually reads. Without it the join times out at IP config.
    if nmcli connection add type wifi ifname "$dev" con-name "$name" \
        autoconnect no ssid "$ssid" \
        802-11-wireless.mode ap 802-11-wireless.band bg \
        802-11-wireless.channel 1 \
        wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK" \
        ipv4.method shared ipv6.method ignore >/dev/null 2>&1 \
        && nmcli -w 30 connection up "$name" >/dev/null 2>&1; then
        up=$((up + 1))
        note "access point $ssid up on $dev"
    else
        note "WARN access point $ssid failed on $dev"
    fi
done

[ "$up" -gt 0 ] || die "no simulated access point came up"

nmcli -w 20 device wifi rescan ifname "$station" >/dev/null 2>&1 || true
sleep 3
nmcli -f SSID,SECURITY,SIGNAL device wifi list ifname "$station" || true
note "ready — $up access point(s), passphrase $PSK"
