#!/usr/bin/env bash
# Headphones follow audible playback, not an open browser media player.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MP="$ROOT/stow/shell/.config/quickshell/modern/Services/AudioBluetoothMultipoint.qml"
BT="$ROOT/stow/shell/.config/quickshell/modern/Services/AudioBluetooth.qml"
WP="$ROOT/stow/pipewire/.config/wireplumber/wireplumber.conf.d/51-bluetooth.conf"
FAIL=0
err() { printf 'test-audio-bluetooth: FAIL %s\n' "$*" >&2; FAIL=1; }

grep -q 'PwNodePeakMonitor' "$MP" || err "peak monitor missing"
grep -q 'soundFloor' "$MP" || err "silence floor missing"
grep -q 'wantSink' "$BT" || err "sink grab is not gated on audible playback"
grep -q 'userSink' "$BT" || err "manual connect is not distinguished"
grep -q 'bluez5.dummy-avrcp-player = true' "$WP" || err "AVRCP playback player missing"
grep -q 'session.suspend-timeout-seconds = 5' "$WP" || err "idle A2DP must suspend"
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
