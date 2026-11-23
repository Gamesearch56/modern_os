#!/usr/bin/env bash
# Bring a Wi-Fi network up, drop it, or delete its saved profile.
# Quickshell's connectWithPsk can store a secret without activating the
# profile, which leaves the network saved and inert. nmcli activates it,
# and a failed password attempt does not keep that profile.
#
# A password is read from stdin (`connect SSID -`) and written into a
# 0600 keyfile. argv is world-readable in /proc, so nmcli never sees the
# secret on its command line. `connection import type keyfile` is a VPN
# plugin name, not this file format, so it fails before the password is
# checked and a right password looks the same as a wrong one. libnm
# reads the keyfile and adds the profile over D-Bus instead.
#
# Exit codes the shell and the installer map to a message:
#   0 ok  1 failed  2 rejected input  3 wrong password
#   4 network not in range  5 timed out  6 unsupported security
set -euo pipefail

# Status lines are how the installer leaves "Checking the password…".
# On a pipe, bash buffers them until the script exits, so a slow join
# looks stuck on that sentence the whole time.
if [[ -z ${WIFI_JOIN_LINEBUF:-} ]] && command -v stdbuf >/dev/null 2>&1; then
    export WIFI_JOIN_LINEBUF=1
    exec stdbuf -oL -eL "$0" "$@"
fi

NMCLI="${MODERN_NMCLI:-nmcli}"
SECRETS_DIR="${MODERN_WIFI_SECRETS_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"

# nmcli --wait does not return while a scan or a secret prompt holds the
# client, and the installer then stays on "Checking the password…".
nmcli_to() {
    local seconds=$1
    shift
    timeout -k 2 "$seconds" "$NMCLI" "$@"
}

die() {
    installer_log "rejected $*"
    printf 'wifi-join: %s\n' "$*" >&2
    exit 2
}

# The install chroot cannot see the live /tmp. This directory is
# bind-mounted into it and copied to /var/log/modern-installer.
installer_log() {
    local dir=${MODERN_INSTALLER_LOG:-/run/modern/installer} line=$1
    [[ -d $dir && -w $dir ]] || return 0
    line=${line//$'\n'/ }
    printf '%s %s\n' "$(date -Is 2>/dev/null || date)" "${line:0:800}" >>"$dir/wifi.log" 2>/dev/null || true
}

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
    err=$(LC_ALL=C nmcli_to 18 -w 18 "$@" 2>&1 >/dev/null) || rc=$?
    [[ $rc -ne 0 ]] || return 0
    printf '%s\n' "$err" >&2
    installer_log "nmcli rc=$rc $err"
    # 124 is timeout's own exit. 137 is the kill that follows if nmcli ignores TERM.
    [[ $rc -ne 3 && $rc -ne 124 && $rc -ne 137 ]] || return 5
    if [[ $rc -eq 10 || $err == *"could not be found"* || $err == *"No network with SSID"* ]]; then
        return 4
    fi
    # nmcli says "802.1X supplicant took too long to authenticate", not
    # the journal's hyphenated reason. That is a timeout, not a bad key.
    if [[ $err == *"took too long"* || $err == *"(11)"* ]]; then
        return 5
    fi
    # A wrong key is reason 7, 8, 9 or 10. The sentence is "supplicant
    # failed", not "supplicant-failed", so the hyphenated names never
    # matched and every password looked like a generic failure.
    if [[ $err == *"(7)"* || $err == *"(8)"* || $err == *"(9)"* || $err == *"(10)"* \
        || $err == *[Ss]ecret* || $err == *"new key"* \
        || $err == *"supplicant failed"* || $err == *"supplicant disconnected"* \
        || $err == *"supplicant configuration failed"* \
        || $err == *supplicant-disconnect* || $err == *supplicant-failed* \
        || $err == *supplicant-config-failed* ]]; then
        return 3
    fi
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

# Keyfile values treat a backslash as an escape. A space is literal.
kf_escape() {
    local s=$1
    s=${s//\\/\\\\}
    printf '%s' "$s"
}

PW_DIR=""
cleanup_pw() {
    [[ -z $PW_DIR ]] || rm -rf "$PW_DIR"
    PW_DIR=""
}
trap cleanup_pw EXIT

# Prints nothing. Exit 0 once NetworkManager has the profile in the file.
add_keyfile() {
    local file=$1 helper
    helper=${MODERN_WIFI_ADD:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wifi-join-add.py}
    "$helper" "$file"
}

# python-gobject is what libnm needs. The live image did not ship it, so
# every password failed before NetworkManager saw it. Root loads the same
# 0600 keyfile from NetworkManager's directory instead.
load_saved_keyfile() {
    local file=$1 uuid=$2 dir dest
    dir=${MODERN_WIFI_CONN_DIR:-/etc/NetworkManager/system-connections}
    [[ -d $dir && -w $dir ]] || return 1
    dest="$dir/modern-${uuid}.nmconnection"
    install -m 600 "$file" "$dest" || return 1
    nmcli_to 8 connection load "$dest"
}

connect_psk() {
    local ssid=$1 psk=$2 sec km out uuid rc=0 file hidden=0
    # The installer already showed this network, so it knows the security.
    # Listing again waits on a scan and the screen stays on "Looking for…".
    printf 'status:lookup\n'
    if [[ -n ${WIFI_JOIN_SECURITY:-} && ${WIFI_JOIN_SECURITY} != -- ]]; then
        sec=$WIFI_JOIN_SECURITY
    else
        sec=$(ap_security "$ssid") || return 4
    fi
    km=$(key_mgmt "$sec") || return 6
    installer_log "connect key-mgmt=$km"
    printf 'status:password\n'
    forget_ssid "$ssid"
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
    [[ -n $uuid ]] || return 1
    # The secret is in the profile before activation, so NetworkManager
    # does not open a password window this screen cannot show. One try
    # made a dropped Realtek handshake look like a wrong password and a
    # right one the same. Three tries still finish inside the installer's
    # limit. A random MAC is rejected by the same chips. Forcing PMF
    # makes those chips drop a correct password too, so it stays at the
    # default. passwd-file supplies the secret again at activation, in
    # case the profile stored the key where no agent can read it.
    PW_DIR=$(umask 077 && mktemp -d "$SECRETS_DIR/wifi-join.XXXXXX")
    file="$PW_DIR/wifi.nmconnection"
    {
        printf '%s\n' '[connection]' "id=$(kf_escape "$ssid")" "uuid=$uuid" 'type=wifi' 'auth-retries=3' 'autoconnect=true' ''
        printf '%s\n' '[wifi]' 'mode=infrastructure' 'powersave=2' \
            "ssid=$(kf_escape "$ssid")" ''
        printf '%s\n' '[wifi-security]' "key-mgmt=$km" "psk=$(kf_escape "$psk")" ''
        printf '%s\n' '[ipv4]' 'method=auto' '' '[ipv6]' 'method=auto' ''
    } >"$file"
    # Text after the first colon is the secret, so a colon in the
    # password stays part of it.
    printf '802-11-wireless-security.psk:%s\n' "$psk" >"$PW_DIR/passwd"
    chmod 600 "$file" "$PW_DIR/passwd"
        # libnm reads the file. nmcli's "import type keyfile" looks for a VPN
    # plugin of that name and returns before the password is ever tried.
    # The live image's helper needs python-gobject. When that import
    # fails, root can still load the same keyfile. The secret stays in
    # the file, not on argv, and a wrong password is still exit 3.
    # Activate against the access point from the scan. A profile brought
    # up on its own never associates on the Realtek chip in these laptops.
    rc_add=0
    out=$(WIFI_JOIN_ACTIVATE=1 add_keyfile "$file" 2>&1) || rc_add=$?
    printf '%s\n' "$out" >&2
    # The helper's text is the reason a later report can name. A line
    # that contains the password is dropped rather than written out.
    # grep -c reads the whole line, so pipefail cannot hide a match.
    hidden=0
    if [[ -n $psk ]]; then
        hidden=$(printf '%s' "$out" | grep -F -c -- "$psk" || true)
    fi
    if [[ ${hidden:-0} != 0 ]]; then
        installer_log "helper rc=$rc_add output-hidden"
    else
        installer_log "helper rc=$rc_add ${out//$'\n'/ }"
    fi
    if [[ $rc_add -eq 0 && $out == *activated* ]]; then
        cleanup_pw
        return 0
    fi
    if [[ $rc_add -eq 3 ]]; then
        cleanup_pw
        forget_ssid "$ssid"
        return 3
    fi
    if [[ $rc_add -ne 0 ]] && ! load_saved_keyfile "$file" "$uuid"; then
        cleanup_pw
        forget_ssid "$ssid"
        return 1
    fi
    printf 'status:address\n'
    nm_up connection up uuid "$uuid" passwd-file "$PW_DIR/passwd" || rc=$?
    cleanup_pw
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
        nmcli_to 4 device disconnect "$dev" >/dev/null 2>&1 || true
    done < <(nmcli_to 4 -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
}

cmd_connect() {
    local ssid=$1
    local from=${2-}
    local psk="" saved rc=0 passfile=${WIFI_JOIN_PASSFILE:-}
    # Closing the installer's stdin pipe before this process reads it
    # made every password, right or wrong, look like a missing one.
    # The password file is the copy that does not depend on that pipe.
    installer_log "connect begin stdin=$([[ $from == - ]] && printf yes || printf no) passfile=$([[ -n $passfile ]] && printf yes || printf no)"
    valid_label "$ssid" || die "rejected network name"
    if [[ -n $passfile && -r $passfile ]]; then
        IFS= read -r psk <"$passfile" || true
        rm -f -- "$passfile"
    fi
    if [[ $from == - ]]; then
        if [[ -z $psk ]]; then
            IFS= read -r psk || true
        fi
        [[ -n $psk ]] || die "missing password"
        # WPA passphrases are 8-63 characters, or 64 hex digits.
        if [[ ${#psk} -lt 8 || ${#psk} -gt 64 ]]; then
            installer_log "rejected password length rc=3"
            exit 3
        fi
        connect_psk "$ssid" "$psk" || rc=$?
        installer_log "finished rc=$rc"
        exit "$rc"
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
