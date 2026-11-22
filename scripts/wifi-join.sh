#!/usr/bin/env bash
# Bring a Wi-Fi network up, drop it, or delete its saved profile.
# Quickshell's connectWithPsk can store a secret without activating the
# profile, which leaves the network saved and inert. nmcli activates it,
# and a failed password attempt does not keep that profile.
#
# A password is read from stdin (`connect SSID -`) and handed to nmcli in
# a 0600 passwd-file: argv is world-readable in /proc. NetworkManager
# stores a secret that arrives that way on the first connect.
#
# Exit codes the shell and the installer map to a message:
#   0 ok  1 failed  2 rejected input  3 wrong password
#   4 network not in range  5 timed out  6 unsupported security
set -euo pipefail

NMCLI="${MODERN_NMCLI:-nmcli}"
SECRETS_DIR="${MODERN_WIFI_SECRETS_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"

# nmcli --wait does not return while a scan or a secret prompt holds the
# client, and the installer then stays on "Checking the password…".
nmcli_to() {
    local seconds=$1
    shift
    timeout -k 2 "$seconds" "$NMCLI" "$@"
}

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
        ssid=$(nmcli_to 4 -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)
        ssid=${ssid//[$'\n\r']/}
        [[ $ssid == "$want" ]] || continue
        printf '%s\n' "$uuid"
    done < <(nmcli_to 4 -t -f UUID,TYPE connection show 2>/dev/null || true)
}

forget_ssid() {
    local uuid
    while IFS= read -r uuid; do
        [[ -n $uuid ]] || continue
        nmcli_to 4 connection delete uuid "$uuid" >/dev/null || true
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

# Runs an activating nmcli call and turns its failure into our exit code.
# LC_ALL=C because the reason is only in nmcli's message text.
nm_up() {
    local err rc=0
    err=$(LC_ALL=C nmcli_to 25 -w 25 "$@" 2>&1 >/dev/null) || rc=$?
    [[ $rc -ne 0 ]] || return 0
    printf '%s\n' "$err" >&2
    # 124 is timeout's own exit. 137 is the kill that follows if nmcli ignores TERM.
    [[ $rc -ne 3 && $rc -ne 124 && $rc -ne 137 ]] || return 5
    if [[ $rc -eq 10 || $err == *"could not be found"* || $err == *"No network with SSID"* ]]; then
        return 4
    fi
    [[ $err != *[Ss]ecrets* ]] || return 3
    return 1
}

# SECURITY never holds a colon, so with escaping off the SSID is
# everything after the first one.
ap_security() {
    local want=$1 line
    while IFS= read -r line; do
        [[ ${line#*:} == "$want" ]] || continue
        printf '%s\n' "${line%%:*}"
        return 0
    # --rescan no: a plain list waits for a scan that may already be running,
    # and Connect stays on "Connecting…" until that scan ends.
    # -w: even --rescan no can sit on a scan NetworkManager already started.
    done < <(nmcli_to 4 -w 4 -t -e no -f SECURITY,SSID device wifi list --rescan no 2>/dev/null || true)
    return 1
}

# WPA2/WPA3 transition networks take wpa-psk. Enterprise (802.1X), WEP
# and OWE have no password field here.
key_mgmt() {
    case " $1 " in
        *802.1X*) return 1 ;;
        *" WPA1 "* | *" WPA2 "*) printf 'wpa-psk\n' ;;
        *" WPA3 "*) printf 'sae\n' ;;
        *) return 1 ;;
    esac
}

# passwd-file values are backslash-unescaped and space-trimmed.
psk_line() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s// /\\ }
    s=${s//$'\t'/\\t}
    printf '802-11-wireless-security.psk:%s\n' "$s"
}

PW_FILE=""
trap '[[ -z $PW_FILE ]] || rm -f "$PW_FILE"' EXIT

connect_psk() {
    local ssid=$1 psk=$2 sec km out uuid rc=0
    # The installer already showed this network, so it knows the security.
    # Listing again waits on a scan and the screen stays on "Looking for…".
    printf 'status:lookup\n'
    if [[ -n ${WIFI_JOIN_SECURITY:-} && ${WIFI_JOIN_SECURITY} != -- ]]; then
        sec=$WIFI_JOIN_SECURITY
    else
        sec=$(ap_security "$ssid") || return 4
    fi
    km=$(key_mgmt "$sec") || return 6
    printf 'status:password\n'
    forget_ssid "$ssid"
    # Flags 2 only while the profile is created, so adding it does not open
    # a password window this screen cannot show. Flags 0 before activation:
    # the system stores the secret from the passwd-file. Leaving 2 in place
    # drops the password, so the network never reconnects and the next try
    # is reported as a wrong password.
    out=$(LC_ALL=C nmcli_to 12 connection add type wifi con-name "$ssid" ssid "$ssid" \
        wifi-sec.key-mgmt "$km" 802-11-wireless-security.psk-flags 2 2>&1) || {
        printf '%s\n' "$out" >&2
        return 1
    }
    uuid=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<<"$out" | tail -n1 || true)
    [[ -n $uuid ]] || { forget_ssid "$ssid"; return 1; }
    # One try. The default keeps asking, so a wrong password never returns
    # and the installer cannot accept a different one.
    nmcli_to 8 connection modify uuid "$uuid" connection.auth-retries 1 >/dev/null || true
    nmcli_to 8 connection modify uuid "$uuid" connection.autoconnect yes >/dev/null || true
    nmcli_to 8 connection modify uuid "$uuid" 802-11-wireless-security.psk-flags 0 >/dev/null || true
    PW_FILE=$(umask 077 && mktemp "$SECRETS_DIR/wifi-join.XXXXXX")
    psk_line "$psk" >"$PW_FILE"
    printf 'status:address\n'
    nm_up connection up uuid "$uuid" passwd-file "$PW_FILE" || rc=$?
    rm -f "$PW_FILE"
    PW_FILE=""
    if [[ $rc -ne 0 ]]; then
        stop_wifi_attempt
        forget_ssid "$ssid"
    fi
    return "$rc"
}

# A failed activation can stay in "connecting" after nmcli has returned.
stop_wifi_attempt() {
    local dev typ state
    while IFS=: read -r dev typ state; do
        [[ $typ == wifi && -n $dev && $dev != "--" ]] || continue
        case $state in
            connecting | configuring | need-auth | ip-config | ip-check | secondaries) ;;
            *) continue ;;
        esac
        "$NMCLI" device disconnect "$dev" >/dev/null 2>&1 || true
    done < <("$NMCLI" -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
}

cmd_connect() {
    local ssid=$1
    local from=${2-}
    local psk="" saved rc=0
    valid_label "$ssid" || die "rejected network name"
    if [[ $from == - ]]; then
        IFS= read -r psk || true
        [[ -n $psk ]] || die "missing password"
        # WPA passphrases are 8-63 characters, or 64 hex digits.
        [[ ${#psk} -ge 8 && ${#psk} -le 64 ]] || exit 3
        connect_psk "$ssid" "$psk" || exit $?
        return 0
    fi
    [[ -z $from ]] || die "pass the password on stdin with -"
    if saved=$(first_uuid "$ssid"); then
        nm_up connection up uuid "$saved" || rc=$?
    else
        nm_up device wifi connect "$ssid" || rc=$?
    fi
    exit "$rc"
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
    # NetworkManager often autoconnects on its own; a second `connection
    # up` would tear that activation down and start it over.
    ! device_busy "$dev" || return 0
    "$NMCLI" -w 15 device wifi list --rescan yes >/dev/null || true
    ! device_busy "$dev" || return 0
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

# NM device states 40 (prepare) through 100 (activated) mean a connection
# is already on its way up or up.
device_busy() {
    local state
    state=$(LC_ALL=C "$NMCLI" -g GENERAL.STATE device show "$1" 2>/dev/null || true)
    state=${state%% *}
    [[ $state =~ ^[0-9]+$ ]] || return 1
    [[ $state -ge 40 && $state -le 100 ]]
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
    die "usage: wifi-join.sh connect SSID [-] | forget SSID | disconnect [SSID] | wake [SSID]"
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
