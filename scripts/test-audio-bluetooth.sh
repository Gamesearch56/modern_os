#!/usr/bin/env bash
# Headphones follow audible playback, not an open browser media player.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MP="$ROOT/stow/shell/.config/quickshell/modern/Services/AudioBluetoothMultipoint.qml"
BT="$ROOT/stow/shell/.config/quickshell/modern/Services/AudioBluetooth.qml"
WP="$ROOT/stow/pipewire/.config/wireplumber/wireplumber.conf.d/51-bluetooth.conf"
HOLD="$ROOT/stow/shell/.config/quickshell/modern/Services/AudioBluetoothHold.qml"
HOLD_CONF="$ROOT/stow/pipewire/.config/pipewire/pipewire.conf.d/60-modern-headset-hold.conf"
AUDIO="$ROOT/stow/shell/.config/quickshell/modern/Services/Audio.qml"
FAIL=0
err() { printf 'test-audio-bluetooth: FAIL %s\n' "$*" >&2; FAIL=1; }

grep -q 'PwNodePeakMonitor' "$MP" || err "peak monitor missing"
grep -q 'soundFloor' "$MP" || err "silence floor missing"
grep -q 'wantSink' "$BT" || err "sink grab is not gated on audible playback"
grep -q 'userSink' "$BT" || err "manual connect is not distinguished"
grep -q 'bluez5.dummy-avrcp-player = true' "$WP" || err "AVRCP playback player missing"
grep -q 'session.suspend-timeout-seconds = 5' "$WP" || err "idle A2DP must suspend"
if grep -q 'disconnectDevice' "$MP"; then
    err "idle must route away, not drop the multipoint connection"
fi
grep -q '_hasSink' "$MP" || err "a link without a sink is not reconnected"
grep -q '_btSinkVolume' "$MP" || err "a headset restored at 0 volume stays silent"
grep -q 'hold.park()' "$MP" || err "idle routes to the speakers instead of the headset hold"
grep -q 'node.name = "modern.headset-hold"' "$HOLD_CONF" || err "headset hold sink missing"
grep -q "nodeName: \"modern.headset-hold\"" "$HOLD" || err "hold service does not match the sink name"
grep -q 'hold.isHold(n)' "$AUDIO" || err "hold sink is listed as a device"
grep -q 'bt.hold.isHold(n)' "$BT" || err "hold sink is remembered as the last speaker"
if grep -q 'session.suspend-timeout-seconds = 0' "$WP"; then
    err "idle A2DP transport is pinned"
fi
for lang in en de; do
    jq -e '.settings.hints.autoSwitchBluetooth | length > 0' \
        "$ROOT/stow/modern/.config/modern/translations/${lang}.json" >/dev/null \
        || err "hint missing in ${lang}"
done

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-audio-bluetooth: ok\n'
