#!/usr/bin/env bash
# Auto-switch follows the headset's connection: its sink appearing makes
# it the speaker, its sink going away restores the previous one. Nothing
# connects a headset or moves the output while it is not connected.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVC="$ROOT/stow/shell/.config/quickshell/modern/Services"
BT="$SVC/AudioBluetooth.qml"
FAIL=0
err() { printf 'test-audio-bluetooth: FAIL %s\n' "$*" >&2; FAIL=1; }

grep -q 'freshSinks' "$BT" || err "a newly connected headset does not become the speaker"
grep -q '_armSettle' "$BT" || err "a disconnect does not restore the previous speaker"
grep -q 'audio.lastSink' "$BT" || err "the previous speaker is not remembered"
if grep -q 'connectDevice' "$BT"; then
    err "auto-switch must not connect a headset itself"
fi
for gone in AudioBluetoothMultipoint.qml AudioBluetoothHold.qml; do
    [ ! -e "$SVC/$gone" ] || err "$gone still routes audio without a connected headset"
    if grep -q "${gone%.qml}" "$SVC/qmldir" "$SVC/Audio.qml"; then
        err "${gone%.qml} is still registered"
    fi
done
if grep -rq 'connectDevice(.*, ' "$ROOT/stow/shell/.config/quickshell/modern"; then
    err "connectDevice callers still pass the removed fromUser flag"
fi
for lang in en de; do
    jq -e '.settings.hints.autoSwitchBluetooth | length > 0' \
        "$ROOT/stow/modern/.config/modern/translations/${lang}.json" >/dev/null \
        || err "hint missing in ${lang}"
done

BTQML="$SVC/Bluetooth.qml"
LINK="$SVC/BluetoothLink.qml"
WP="$ROOT/stow/pipewire/.config/wireplumber/wireplumber.conf.d/51-bluetooth.conf"
if grep -q 'a.discovering = on' "$BTQML"; then
    err "powering the adapter must not leave discovery running"
fi
if ! grep -q 'discovering = false' "$BTQML"; then
    err "a finished search must stop discovery"
fi
if ! grep -q 'BluetoothLink.shadowed' "$BTQML"; then
    err "a second advert of a saved headset is still listed"
fi
if ! grep -q '_pairing = !(device.paired || device.bonded)' "$LINK"; then
    err "a bonded headset must connect without a new pair, and one without a bond must pair"
fi
if ! grep -q 'function bondLost' "$LINK" || ! grep -q 'settings.bluetooth.bondLost' "$LINK"; then
    err "a saved headset whose bond is gone is not reported as needing pairing mode"
fi
BTC="$SVC/BluetoothClassic.qml"
grep -q 'singleton BluetoothClassic 1.0 BluetoothClassic.qml' "$SVC/qmldir" || err "BluetoothClassic is not registered"
if ! grep -q 'BluetoothClassic.pair(device)' "$LINK" || grep -q 'device.pair()' "$LINK" \
    || ! grep -q 'scan bredr' "$BTC"; then
    err "a headset is paired without a classic scan first, so BlueZ pairs over LE and the bond is lost after the case"
fi
if ! grep -q '"bluetoothctl", "--agent", "NoInputNoOutput"' "$BTC" || grep -q 'd\.pair()\|device\.pair()' "$BTC" \
    || ! grep -q 'trust succeeded' "$BTC"; then
    err "pairing runs without a BlueZ agent, so Pair is rejected and a device-started pairing is only temporary"
fi
if ! grep -q 'Bluetooth.setDiscovering(false)' "$BTC" || ! grep -q 'onDiscoveringChanged' "$BTC" \
    || ! grep -q 'bluetoothStopWaitMs' "$BTC" || ! grep -q 'BluetoothClassic.scanning' "$BTQML"; then
    err "the classic scan does not wait for the shell's own search to stop, so BlueZ merges in LE and the pair lands on it"
fi
if ! sed -n '/function setDiscovering/,/^    }/p' "$BTQML" | grep -q 'refreshKick.stop()'; then
    err "stopping discovery leaves a pending refresh that restarts the search under a pairing"
fi
WARM="$SVC/BluetoothWarmup.qml"
[ -e "$WARM" ] || err "BluetoothWarmup.qml is missing"
grep -q 'singleton BluetoothWarmup 1.0 BluetoothWarmup.qml' "$SVC/qmldir" || err "BluetoothWarmup is not registered"
if ! grep -q 'BluetoothWarmup.warm(freshSinks' "$BT" || grep -q 'setDefaultSink(freshSinks' "$BT"; then
    err "a reconnected headset becomes the speaker before its warm-up, so video runs out of sync"
fi
grep -q 'durationBluetoothWarm:' "$ROOT/stow/shell/.config/quickshell/modern/Commons/Motion.qml" \
    || err "Motion has no durationBluetoothWarm"
if ! grep -q 'BluetoothAudio.ask(device)' "$LINK"; then
    err "connecting a headset with a bare link calls Connect, which BlueZ refuses"
fi
if grep -q 'Logger.error("Bluetooth"' "$LINK"; then
    err "a refused headset raises a shell-error toast"
fi
grep -q 'settings.bluetooth.repairBody' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/bluetooth/Section.qml" \
    || err "the connect dialog does not say the headset must be paired again"
if ! grep -q 'device.trusted' "$LINK" || ! grep -q 'connectFailed' "$LINK"; then
    err "a failed connect is not reported"
fi
if ! grep -q 'bluez5.auto-connect = \[ \]' "$WP" \
    || ! grep -q 'autoswitch-to-headset-profile = false' "$WP" \
    || ! grep -q 'dummy-avrcp-player = false' "$WP"; then
    err "wireplumber still pages headsets and holds the headset profile"
fi
BTA="$SVC/BluetoothAudio.qml"
grep -q 'singleton BluetoothAudio 1.0 BluetoothAudio.qml' "$SVC/qmldir" || err "BluetoothAudio is not registered"
if ! grep -q 'BluetoothAudio.linked' "$LINK" || ! grep -q 'BluetoothAudio.linked' "$BTQML"; then
    err "a headset with a bare link and no audio still counts as connected"
fi
if ! grep -q 'ConnectProfile' "$BTA" || ! grep -q '!d.connected' "$BTA"; then
    err "a user Connect on a bare link is not asked for A2DP, or a disconnected headset is paged"
fi
if grep -q 'function watch' "$BTA" || grep -q 'BluetoothAudio.watch' "$BTQML"; then
    err "A2DP is started on every new link, crossing the headset's own and BlueZ's fallback"
fi
profile_ms="$(sed -n 's/.*durationBluetoothProfile: \([0-9]*\).*/\1/p' "$ROOT/stow/shell/.config/quickshell/modern/Commons/Motion.qml")"
[ "${profile_ms:-0}" -ge 3500 ] || err "the A2DP ask must wait past BlueZ's ~3 s fallback (got ${profile_ms:-none} ms)"
grep -q 'Qt.callLater(root._onDevices)' "$BTQML" || err "device changes run inside the _devSig binding"
BTS="$SVC/BluetoothSignal.qml"
grep -q 'singleton BluetoothSignal 1.0 BluetoothSignal.qml' "$SVC/qmldir" || err "BluetoothSignal is not registered"
if ! grep -q 'Bluetooth.refreshing || Bluetooth.discovering' "$BTS" || ! grep -q '"gdbus", "monitor"' "$BTS"; then
    err "Bluetooth RSSI must follow BlueZ signals only while a search runs"
fi
grep -q 'BluetoothSignal.compare(a, b)' "$BTQML" || err "the device list is not ordered by saved, in range, and signal"
WIDGETS="$ROOT/stow/shell/.config/quickshell/modern/Widgets"
for w in MSignal MTag; do
    grep -q "^$w 1.0 $w.qml" "$WIDGETS/qmldir" || err "$w is not registered in Widgets/qmldir"
done
grep -q 'property alias titleAccessory' "$WIDGETS/MListItem.qml" || err "MListItem has no slot beside the title"
MOD="$ROOT/stow/shell/.config/quickshell/modern/Modules"
for list in Settings/sections/network/WifiList.qml Bar/widgets/network/Panel.qml \
    Settings/sections/bluetooth/DeviceList.qml Bar/widgets/bluetooth/Panel.qml; do
    if grep -q '^ *MTag {' "$MOD/$list" || ! grep -q 'titleAccessory: MTag {' "$MOD/$list"; then
        err "the saved pill in $list sits beside the signal bars instead of the name"
    fi
done
for list in Settings/sections/bluetooth/DeviceList.qml Bar/widgets/bluetooth/Panel.qml; do
    if ! grep -q 'Tokens.dimmedOpacity' "$MOD/$list" || grep -q 'enabled: false' "$MOD/$list"; then
        err "a saved Bluetooth device that was not found is not dimmed (and still clickable) in $list"
    fi
done
grep -q 'readonly property real dimmedOpacity' "$ROOT/stow/shell/.config/quickshell/modern/Commons/Tokens.qml" \
    || err "Tokens has no dimmedOpacity"
if command -v node >/dev/null 2>&1; then
    node -e '
        const src = require("fs").readFileSync(process.argv[1], "utf8").replace(".pragma library", "");
        const m = {}; new Function("m", src + "; m.wifi = wifi; m.bluetooth = bluetooth; m.sortWifi = sortWifi;")(m);
        const ok = m.wifi(0.9) === 4 && m.wifi(80) === 4 && m.wifi(0.2) === 1 && m.wifi(0) === 0
            && m.bluetooth(-55) === 4 && m.bluetooth(-85) === 1 && m.bluetooth(undefined) === -1;
        const nets = [{ name: "b", signalStrength: 0.9 }, { name: "a", signalStrength: 0.3, known: true },
            { name: "c", signalStrength: 0.2, connected: true }, { name: "d", signalStrength: 0.95 }];
        const order = m.sortWifi(nets, n => n.name).map(n => n.name).join("");
        process.exit(ok && order === "cabd" ? 0 : 1);
    ' "$SVC/signalLevel.js" || err "signalLevel.js levels or Wi-Fi order (connected, saved, strongest, name) are wrong"
fi
for lang in en de; do
    for key in connecting connectFailed pairFailed connectFailedTitle noAudio bondLost repairBody remembered; do
        jq -e --arg k "$key" '.settings.bluetooth[$k] | length > 0' \
            "$ROOT/stow/modern/.config/modern/translations/${lang}.json" >/dev/null \
            || err "settings.bluetooth.${key} missing in ${lang}"
    done
done

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-audio-bluetooth: ok\n'
