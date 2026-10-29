#!/usr/bin/env bash
# Unprivileged coverage for network-speed.sh. Never hits the network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-network-speed: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-network-speed: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/network-speed.sh"
export MODERN_TEST_FIXTURE=1

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["speed"]>0 and o["bytes"]>0 and o["time"]>0
assert "dns" in o and "connect" in o and str(o["code"])
'; then
    ok "fixture prints a speed JSON object"
else
    err "fixture json: $out"
fi

if grep -F 'Paths.script("network-speed.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/NetworkSpeed.qml" >/dev/null; then
    ok "Settings speed test is this script"
else
    err "NetworkSpeed.qml must run network-speed.sh"
fi

if grep -F -- '--max-time", "8"' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/NetworkSpeed.qml" >/dev/null; then
    err "inline 8s curl must not remain"
else
    ok "no 8s single-stream curl in Settings"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-network-speed: ok\n'
