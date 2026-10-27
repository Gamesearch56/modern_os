#!/usr/bin/env bash
# Bring a Wi-Fi network up, drop it, or delete its saved profile.
# Quickshell's connectWithPsk can store a secret without activating the
# profile, which leaves the network saved and inert. nmcli activates it,
# and a failed password attempt does not keep that profile.
set -euo pipefail

NMCLI="${MODERN_NMCLI:-nmcli}"

die() { printf 'wifi-join: %s\n' "$*" >&2; exit 2; }

valid_label() {
    local s=$1
    [[ -n $s ]] || return 1
    [[ $s != *$'\n'* && $s != *$'\r'* ]] || return 1
    [[ $s != -* ]] || return 1
    [[ ${#s} -le 128 ]] || return 1
}

# UUID and TYPE from `nmcli -t` do not contain the field separator.
wifi_uuids() {
    local want=$1 uuid typ ssid
    while IFS=: read -r uuid typ; do
        [[ -n $uuid && $typ == 802-11-wireless ]] || continue
        ssid=$("$NMCLI" -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)
        ssid=${ssid//[$'\n\r']/}
        [[ $ssid == "$want" ]] || continue
        printf '%s\n' "$uuid"
    done < <("$NMCLI" -t -f UUID,TYPE connection show 2>/dev/null || true)
}

forget_ssid() {
    local uuid
    while IFS= read -r uuid; do
        [[ -n $uuid ]] || continue
        "$NMCLI" connection delete uuid "$uuid" >/dev/null
    done < <(wifi_uuids "$1")
}

first_uuid() {
    local uuid
    while IFS= read -r uuid; do
        [[ -n $uuid ]] || continue
        printf '%s\n' "$uuid"
        return 0
    done < <(wifi_uuids "$1")
    return 1
}

cmd_connect() {
    local ssid=$1
    local psk=${2-}
    local saved
    valid_label "$ssid" || die "rejected network name"
    if [[ -n $psk ]]; then
        [[ $psk != *$'\n'* && $psk != *$'\r'* ]] || die "rejected password"
        [[ ${#psk} -le 128 ]] || die "rejected password"
        forget_ssid "$ssid"
        if ! "$NMCLI" -w 25 device wifi connect "$ssid" password "$psk"; then
            forget_ssid "$ssid"
            exit 1
        fi
        return 0
    fi
    if saved=$(first_uuid "$ssid"); then
        "$NMCLI" -w 25 connection up uuid "$saved"
    else
        "$NMCLI" -w 25 device wifi connect "$ssid"
    fi
}

cmd_forget() {
    local ssid=$1
    valid_label "$ssid" || die "rejected network name"
    forget_ssid "$ssid"
}

# A wifi device that is still powering up reports unavailable. Poll until
# it can scan, then bring the network that was connected back up.
# `device disconnect` blocks autoconnect until it is turned back on.
cmd_wake() {
    local ssid=${1-}
    local dev="" saved="" i=0
    if [[ -n $ssid ]]; then
        valid_label "$ssid" || die "rejected network name"
    fi
    while [[ $i -lt 20 ]]; do
        i=$((i + 1))
        dev=$(wifi_device_ready || true)
        [[ -n $dev ]] && break
        sleep 0.4
    done
    [[ -n $dev ]] || die "wifi device not ready"
    "$NMCLI" device set "$dev" autoconnect yes >/dev/null || true
    "$NMCLI" -w 15 device wifi list --rescan yes >/dev/null || true
    if [[ -n $ssid ]]; then
        saved=$(first_uuid "$ssid" || true)
    else
        saved=$(newest_wifi_uuid || true)
    fi
    [[ -n $saved ]] || return 0
    "$NMCLI" connection modify "$saved" connection.autoconnect yes >/dev/null || true
    "$NMCLI" -w 25 connection up uuid "$saved" || true
}

newest_wifi_uuid() {
    local uuid typ stamp best="" best_stamp=0
    while IFS=: read -r uuid typ stamp; do
        [[ $typ == 802-11-wireless && -n $uuid && $stamp =~ ^[0-9]+$ ]] || continue
        if [[ $stamp -gt $best_stamp ]]; then
            best=$uuid
            best_stamp=$stamp
        fi
    done < <("$NMCLI" -t -f UUID,TYPE,TIMESTAMP connection show 2>/dev/null || true)
    [[ -n $best ]] || return 1
    printf '%s\n' "$best"
}

wifi_device_ready() {
    local dev typ state
    while IFS=: read -r dev typ state; do
        [[ $typ == wifi && -n $dev && $state != unavailable && $state != unmanaged ]] || continue
        printf '%s\n' "$dev"
        return 0
    done < <("$NMCLI" -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
    return 1
}

cmd_disconnect() {
    local want=${1-}
    local uuid typ dev ssid
    if [[ -n $want ]]; then
        valid_label "$want" || die "rejected network name"
    fi
    while IFS=: read -r uuid typ dev; do
        [[ $typ == 802-11-wireless && -n $dev && $dev != "--" ]] || continue
        if [[ -n $want ]]; then
            ssid=$("$NMCLI" -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)
            ssid=${ssid//[$'\n\r']/}
            [[ $ssid == "$want" ]] || continue
        fi
        "$NMCLI" device disconnect "$dev"
    done < <("$NMCLI" -t -f UUID,TYPE,DEVICE connection show --active 2>/dev/null || true)
}

usage() {
    die "usage: wifi-join.sh connect SSID [PASSWORD] | forget SSID | disconnect [SSID] | wake [SSID]"
}

[[ $# -ge 1 ]] || usage
case $1 in
    connect)
        [[ $# -eq 2 || $# -eq 3 ]] || usage
        cmd_connect "$2" "${3-}"
        ;;
    forget)
        [[ $# -eq 2 ]] || usage
        cmd_forget "$2"
        ;;
    disconnect)
        [[ $# -eq 1 || $# -eq 2 ]] || usage
        cmd_disconnect "${2-}"
        ;;
    wake)
        [[ $# -eq 1 || $# -eq 2 ]] || usage
        cmd_wake "${2-}"
        ;;
    *) usage ;;
esac
