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
if ! grep -q '_pairing = !root.isRemembered' "$LINK"; then
    err "a saved headset must be connected without a new pair"
fi
if ! grep -q 'device.trusted' "$LINK" || ! grep -q 'connectFailed' "$LINK"; then
    err "a failed connect is not reported"
fi
if ! grep -q 'bluez5.auto-connect = \[ \]' "$WP" \
    || ! grep -q 'autoswitch-to-headset-profile = false' "$WP" \
    || ! grep -q 'dummy-avrcp-player = false' "$WP"; then
    err "wireplumber still pages headsets and holds the headset profile"
fi
for lang in en de; do
    for key in connecting connectFailed pairFailed connectFailedTitle; do
        jq -e --arg k "$key" '.settings.bluetooth[$k] | length > 0' \
            "$ROOT/stow/modern/.config/modern/translations/${lang}.json" >/dev/null \
            || err "settings.bluetooth.${key} missing in ${lang}"
    done
done

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-audio-bluetooth: ok\n'
