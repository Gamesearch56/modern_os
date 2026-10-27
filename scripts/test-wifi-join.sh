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
if [[ $* == *'connection delete uuid home-uuid'* ]]; then
    printf 'gone\n' >"$state"
    exit 0
fi
if [[ $* == *'connection delete uuid new-uuid'* ]]; then
    rm -f "${state}.left"
    exit 0
fi
if [[ ${FAIL_CONNECT:-0} -eq 1 && $* == *'device wifi connect'* ]]; then
    printf 'left\n' >"${state}.left"
    exit 1
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

run_join() {
    : >"$LOG"
    LOG="$LOG" WIFI_JOIN_STATE="$STATE" MODERN_NMCLI="$TMP/nmcli" "$JOIN" "$@"
}

if run_join connect 'Cafe Net' 'correct pass'; then
    if grep -F 'connection delete uuid home-uuid' "$LOG" >/dev/null \
        && grep -F 'device wifi connect Cafe Net password correct pass' "$LOG" >/dev/null \
        && ! grep -F 'device disconnect enp0s1' "$LOG" >/dev/null; then
        ok "password connect replaces the saved profile and activates it"
    else
        err "password connect did not activate: $(tr '\n' ' ' <"$LOG")"
    fi
else
    err "password connect exited non-zero"
fi

printf 'home\n' >"$STATE"
rm -f "$STATE.left"
if FAIL_CONNECT=1 run_join connect 'Cafe Net' 'wrong' ; then
    err "failed password connect should exit non-zero"
else
    deletes=$(grep -c 'connection delete uuid' "$LOG" || true)
    if [[ $deletes -ge 2 && ! -f $STATE.left && $(head -n1 "$STATE") == gone ]]; then
        ok "failed password connect drops the profile again"
    else
        err "failed password left a profile (deletes=$deletes state=$(head -n1 "$STATE"))"
    fi
fi

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

if [[ $FAIL -ne 0 ]]; then
    exit 1
fi
