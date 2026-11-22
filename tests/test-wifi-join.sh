#!/usr/bin/env bash
# wifi-join.sh activates a network instead of only storing a profile,
# and a failed password does not leave that profile behind.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-wifi-join: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-wifi-join: ok %s\n' "$*"; }

JOIN="$ROOT/scripts/wifi-join.sh"
NET="$ROOT/stow/shell/.config/quickshell/modern/Services/Network.qml"
JOIN_QML="$ROOT/stow/shell/.config/quickshell/modern/Services/NetworkJoin.qml"
LIST="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/network/WifiList.qml"
SECTION="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/network/Section.qml"
WIDGET="$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/network/Widget.qml"
ROW="$ROOT/iso/releng/calamares-modernnet/ModernNetRow.cpp"
PAGE="$ROOT/iso/releng/calamares-modernnet/ModernNetPage.cpp"
NM="$ROOT/iso/releng/calamares-modernnet/ModernNetNm.cpp"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/nmcli.log"
STATE="$TMP/state"
printf 'home\n' >"$STATE"

cat >"$TMP/nmcli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$LOG"
state=${WIFI_JOIN_STATE:?}
if [[ ${HANG_SHOW:-0} -eq 1 && $* == *'connection show'* ]]; then
    sleep 30
    exit 0
fi
if [[ $* == *'connection delete uuid home-uuid'* ]]; then
    printf 'gone\n' >"$state"
    exit 0
fi
if [[ $* == *'connection delete uuid new-uuid'* ]]; then
    rm -f "${state}.left"
    exit 0
fi
if [[ $* == *'device wifi list'* ]]; then
    if [[ ${HANG_LIST:-0} -eq 1 ]]; then
        sleep 30
    fi
    printf 'WPA2 WPA3:Cafe Net\nWPA2 802.1X:Office\n'
    exit 0
fi
if [[ $* == *'connection add '* ]]; then
    printf 'left\n' >"${state}.left"
    printf "Connection '%s' (00000000-0000-4000-8000-00000000abcd) successfully added.\n" Cafe
    exit 0
fi
if [[ $* == *'connection up uuid 00000000-0000-4000-8000-00000000abcd passwd-file '* ]]; then
    pw=${!#}
    stat -c '%a' "$pw" >"${state}.mode"
    cat "$pw" >"${state}.secret"
    if [[ -n ${SLOW_CONNECT:-} ]]; then
        printf 'up\n' >"${state}.waiting"
        sleep "$SLOW_CONNECT"
    fi
    if [[ ${FAIL_CONNECT:-0} -eq 1 ]]; then
        printf 'Error: Connection activation failed: Secrets were required, but not provided.\n' >&2
        exit 4
    fi
    exit 0
fi
if [[ ${FAIL_RANGE:-0} -eq 1 && $* == *'device wifi connect'* ]]; then
    printf "Error: No network with SSID 'Cafe Net' found.\n" >&2
    exit 10
fi
if [[ $* == '-t -f UUID,TYPE connection show' ]]; then
    cur=$(head -n1 "$state")
    if [[ $cur == home ]]; then
        printf 'home-uuid:802-11-wireless\n'
    fi
    if [[ -f ${state}.left ]]; then
        printf 'new-uuid:802-11-wireless\n'
    fi
    exit 0
fi
if [[ $* == '-g 802-11-wireless.ssid connection show home-uuid' || $* == '-g 802-11-wireless.ssid connection show new-uuid' ]]; then
    printf 'Cafe Net\n'
    exit 0
fi
if [[ $* == '-t -f UUID,TYPE,DEVICE connection show --active' ]]; then
    printf 'home-uuid:802-11-wireless:wlan0\n'
    printf 'eth-uuid:802-3-ethernet:enp0s1\n'
    exit 0
fi
if [[ $* == '-t -f UUID,TYPE,TIMESTAMP connection show' ]]; then
    printf 'home-uuid:802-11-wireless:10\n'
    exit 0
fi
if [[ $* == '-g GENERAL.STATE device show wlan0' ]]; then
    printf '%s\n' "${WAKE_STATE:-30 (disconnected)}"
    exit 0
fi
if [[ $* == '-t -f DEVICE,TYPE,STATE device status' ]]; then
    tries="${state}.tries"
    n=0
    if [[ -f $tries ]]; then
        n=$(cat "$tries")
    fi
    n=$((n + 1))
    printf '%s\n' "$n" >"$tries"
    if [[ $n -lt 2 ]]; then
        printf 'wlan0:wifi:unavailable\n'
    else
        printf 'wlan0:wifi:disconnected\n'
    fi
    exit 0
fi
exit 0
EOF
chmod +x "$TMP/nmcli" "$JOIN"

expect_rc() {
    if [[ $rc -eq $1 ]]; then ok "$2"; else err "$3"; fi
}

run_join() {
    : >"$LOG"
    LOG="$LOG" WIFI_JOIN_STATE="$STATE" MODERN_NMCLI="$TMP/nmcli" \
        MODERN_WIFI_SECRETS_DIR="$TMP" "$JOIN" "$@"
}

if printf '%s\n' 'correct pass\x' | run_join connect 'Cafe Net' -; then
    if grep -F 'connection delete uuid home-uuid' "$LOG" >/dev/null \
        && grep -F 'connection add type wifi con-name Cafe Net ssid Cafe Net wifi-sec.key-mgmt wpa-psk' "$LOG" >/dev/null \
        && grep -F '802-11-wireless-security.psk-flags 0' "$LOG" >/dev/null \
        && ! grep -F 'correct' "$LOG" >/dev/null \
        && [[ $(cat "$STATE.mode") == 600 ]] \
        && [[ $(cat "$STATE.secret") == '802-11-wireless-security.psk:correct\ pass\\x' ]] \
        && ! compgen -G "$TMP/wifi-join.*" >/dev/null; then
        ok "password goes through a private passwd-file, never argv, and the file is removed"
    else
        err "password connect leaked or did not activate: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "password connect exited non-zero"
fi

printf 'home\n' >"$STATE"
rm -f "$STATE.left"
rc=0
printf 'wrongpass\n' | FAIL_CONNECT=1 run_join connect 'Cafe Net' - 2>/dev/null || rc=$?
deletes=$(grep -c 'connection delete uuid' "$LOG" || true)
if [[ $rc -eq 3 && $deletes -ge 2 && ! -f $STATE.left && $(head -n1 "$STATE") == gone ]]; then
    ok "a refused password exits 3 and drops the profile again"
else
    err "refused password: rc=$rc deletes=$deletes state=$(head -n1 "$STATE")"
fi

rc=0
printf 'shortpw\n' | run_join connect 'Cafe Net' - 2>/dev/null || rc=$?
expect_rc 3 "a password WPA cannot use is refused before nmcli" "short password exited $rc"

rc=0
printf 'longenough\n' | run_join connect 'Office' - 2>/dev/null || rc=$?
expect_rc 6 "an enterprise network reports unsupported security" "enterprise network exited $rc"

rc=0
printf 'longenough\n' | run_join connect 'Elsewhere' - 2>/dev/null || rc=$?
expect_rc 4 "a network that is not in the scan reports out of range" "missing network exited $rc"

rc=0
run_join connect 'Cafe Net' 'argv pass' 2>/dev/null || rc=$?
expect_rc 2 "a password on the command line is refused" "argv password exited $rc"

printf 'home\n' >"$STATE"
rm -f "$STATE.left"
if run_join connect 'Cafe Net'; then
    if grep -F 'connection up uuid home-uuid' "$LOG" >/dev/null \
        && ! grep -F 'password' "$LOG" >/dev/null; then
        ok "saved network connects with its stored secret"
    else
        err "saved connect did not use the profile: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "saved connect exited non-zero"
fi

printf 'gone\n' >"$STATE"
rm -f "$STATE.left"
rc=0
FAIL_RANGE=1 run_join connect 'Cafe Net' 2>/dev/null || rc=$?
expect_rc 4 "nmcli's no-such-network maps to out of range" "open connect out of range exited $rc"

if run_join connect 'Cafe Net'; then
    if grep -F 'device wifi connect Cafe Net' "$LOG" >/dev/null \
        && ! grep -F 'connection up' "$LOG" >/dev/null; then
        ok "unknown open network is activated directly"
    else
        err "open connect used a profile: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "open connect exited non-zero"
fi

printf 'home\n' >"$STATE"
if run_join forget 'Cafe Net'; then
    if grep -F 'connection delete uuid home-uuid' "$LOG" >/dev/null; then
        ok "forget deletes the profile for that name"
    else
        err "forget did not delete"
    fi
else
    err "forget exited non-zero"
fi

if run_join disconnect 'Cafe Net'; then
    if grep -F 'device disconnect wlan0' "$LOG" >/dev/null \
        && ! grep -F 'device disconnect enp0s1' "$LOG" >/dev/null; then
        ok "disconnect drops Wi-Fi and leaves Ethernet"
    else
        err "disconnect touched the wrong device: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "disconnect exited non-zero"
fi

printf 'home\n' >"$STATE"
rm -f "$STATE.tries" "$STATE.left"
if run_join wake 'Cafe Net'; then
    if grep -F 'device wifi list --rescan yes' "$LOG" >/dev/null \
        && grep -F 'device set wlan0 autoconnect yes' "$LOG" >/dev/null \
        && grep -F 'connection up uuid home-uuid' "$LOG" >/dev/null \
        && grep -F 'connection.autoconnect yes' "$LOG" >/dev/null \
        && [[ $(cat "$STATE.tries") -ge 2 ]]; then
        ok "wake waits for the radio, scans, and reconnects the saved network"
    else
        err "wake did not scan and reconnect: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "wake exited non-zero"
fi

rm -f "$STATE.tries"
if run_join wake; then
    if grep -F 'connection up uuid home-uuid' "$LOG" >/dev/null \
        && grep -F 'device wifi list --rescan yes' "$LOG" >/dev/null; then
        ok "wake with no name still scans and reconnects the last network"
    else
        err "wake without a name did not reconnect: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "wake without a name exited non-zero"
fi

rm -f "$STATE.tries"
if WAKE_STATE='100 (connected)' run_join wake 'Cafe Net'; then
    if ! grep -F 'connection up' "$LOG" >/dev/null \
        && ! grep -F -- '--rescan yes' "$LOG" >/dev/null; then
        ok "wake leaves a connection NetworkManager already brought up alone"
    else
        err "wake restarted an activation already in progress: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "wake with an active connection exited non-zero"
fi

printf 'home\n' >"$STATE"
rm -f "$STATE.left" "$STATE.waiting"
: >"$LOG"
printf 'killed mid connect\n' | LOG="$LOG" WIFI_JOIN_STATE="$STATE" MODERN_NMCLI="$TMP/nmcli" \
    MODERN_WIFI_SECRETS_DIR="$TMP" SLOW_CONNECT=1 "$JOIN" connect 'Cafe Net' - 2>/dev/null &
pid=$!
for _ in $(seq 1 50); do
    [[ -f $STATE.waiting ]] && break
    sleep 0.1
done
kill -TERM "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
if [[ -f $STATE.waiting ]] && ! compgen -G "$TMP/wifi-join.*" >/dev/null; then
    ok "a connect killed by a shell reload still removes its passphrase file"
else
    err "passphrase file left behind after SIGTERM"
fi

if run_join connect '-bad' 'x' 2>/dev/null; then
    err "ssid starting with a dash was accepted"
else
    ok "ssid starting with a dash is rejected"
fi

if grep -Fq 'wifi-join.sh' "$JOIN_QML" \
    && grep -Fq 'join.wake' "$NET" \
    && grep -Fq 'linkKind' "$NET" \
    && grep -Fq 'MDialog' "$SECTION" \
    && ! grep -Fq 'PasswordOverlay' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/Module.qml"; then
    ok "settings uses the shared dialog and nmcli join"
else
    err "settings still uses the password overlay or Quickshell connect"
fi

if grep -Fq 'Network.linkKind' "$WIDGET" && grep -Fq 'networkClicked' "$LIST"; then
    ok "bar icon follows Wi-Fi versus Ethernet, list opens the dialog"
else
    err "bar icon or network list was not updated"
fi

if grep -Fq 'forgetSsid' "$NM" && grep -Fq 'Forget' "$ROW" && grep -Fq 'Choose another network' "$PAGE"; then
    ok "installer can forget a saved network and leave a Wi-Fi session"
else
    err "installer wifi actions were not updated"
fi

if grep -Fq 'connection.auth-retries 1' "$JOIN" \
    && grep -Fq 'stop_wifi_attempt' "$JOIN" \
    && grep -Fq -- '--rescan no' "$NM" \
    && grep -Fq 'scanLimit->start( 25000 )' "$NM" \
    && grep -Fq 'joinLimit->start( 40000 )' "$NM" \
    && grep -Fq 'WIFI_JOIN_SECURITY' "$NM" \
    && grep -Fq 'WIFI_JOIN_SECURITY' "$JOIN" \
    && grep -Fq 'm_nm->scanning() || m_nm->connecting()' "$PAGE" \
    && grep -Fq 'if ( m_connecting )' "$NM" \
    && grep -Fq 'm_scan->kill()' "$NM"; then
    ok "a wrong password and a scan both stop so another try can start"
else
    err "wifi connect or scan can stay running"
fi

if grep -Fq '/usr/lib/modern/wifi-join.sh' "$NM" && grep -Fq 'closeWriteChannel' "$NM" \
    && ! grep -Fq 'QStringLiteral( "password" )' "$NM" \
    && grep -Fq 'scripts/wifi-join.sh' "$ROOT/scripts/iso-build.sh" \
    && grep -Fq 'usr/lib/modern/wifi-join.sh' "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" \
    && grep -Fq 'joinProc.write' "$JOIN_QML" && ! grep -Fq 'cmd.push(extra)' "$JOIN_QML"; then
    ok "shell and installer hand the password over stdin"
else
    err "a Wi-Fi password still reaches nmcli argv"
fi

printf 'home\n' >"$STATE"
rm -f "$STATE.left"
: >"$LOG"
if timeout 8 env LOG="$LOG" WIFI_JOIN_STATE="$STATE" HANG_SHOW=1 WIFI_JOIN_SECURITY='WPA2' \
    MODERN_NMCLI="$TMP/nmcli" MODERN_WIFI_SECRETS_DIR="$TMP" \
    "$JOIN" connect 'Cafe Net' - <<<"right-password" >/dev/null; then
    if grep -F 'connection up uuid' "$LOG" >/dev/null \
        && ! grep -F 'right-password' "$LOG" >/dev/null; then
        ok "a stuck profile listing does not hold the password check"
    else
        err "stuck profile listing did not reach activation: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "password check waited on NetworkManager's profile listing"
fi

if timeout 5 env LOG="$LOG" WIFI_JOIN_STATE="$STATE" HANG_LIST=1 WIFI_JOIN_SECURITY='WPA2' \
    MODERN_NMCLI="$TMP/nmcli" MODERN_WIFI_SECRETS_DIR="$TMP" \
    "$JOIN" connect 'Cafe Net' - <<<"right-password" >/dev/null; then
    if ! grep -F 'device wifi list' "$LOG" >/dev/null \
        && grep -F 'wifi-sec.key-mgmt wpa-psk' "$LOG" >/dev/null \
        && ! grep -F 'right-password' "$LOG" >/dev/null; then
        ok "a known network is joined without waiting for another scan"
    else
        err "known security still listed or leaked the password: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "joining with a known security waited on the scan"
fi

if [[ $FAIL -ne 0 ]]; then
    exit 1
fi
