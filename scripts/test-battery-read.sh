#!/usr/bin/env bash
# Unprivileged coverage for battery-read.sh. Never calls upower.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-battery-read: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-battery-read: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/battery-read.sh"
export MODERN_TEST_FIXTURE=1

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

export MODERN_BATTERY_TEXT=$'native-path:          BAT0\npercentage:          87%\nstate:               discharging\ntime to empty:       2.5 hours\nenergy-rate:         11.2 W'
out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["hasBattery"] and o["onBattery"] and not o["charging"]
assert o["percent"]==87 and o["timeSeconds"]==9000 and abs(o["rateWatts"]-11.2)<0.01
'; then
    ok "discharging laptop pack"
else
    err "discharging: $out"
fi

export MODERN_BATTERY_TEXT=$'native-path:          BAT0\npercentage:          41.6%\nstate:               charging\ntime to full:        48 minutes\nenergy-rate:         20 W'
out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["hasBattery"] and o["charging"] and not o["onBattery"]
assert o["percent"]==42 and o["timeToFull"] and o["timeSeconds"]==2880
'; then
    ok "charging still reports a battery"
else
    err "charging: $out"
fi

export MODERN_BATTERY_TEXT=$'native-path:          BAT0\npercentage:          100%\nstate:               fully-charged'
out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["hasBattery"] and o["charging"] and not o["onBattery"] and o["percent"]==100
'; then
    ok "full and plugged in still has a battery"
else
    err "full: $out"
fi

export MODERN_BATTERY_TEXT="line power stuff"
out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
assert json.load(sys.stdin)=={"hasBattery":False}
'; then
    ok "no percentage is AC-only"
else
    err "empty: $out"
fi

export MODERN_BATTERY_TEXT=$'native-path:          BAT0\npercentage:          80%\nstate:               discharging\nenergy:              40.0 Wh\nenergy-empty:        0 Wh\nenergy-full:         50.0 Wh\nenergy-full-design:  60.0 Wh\nenergy-rate:         10.0 W\nvoltage:             12.1 V\ncharge-cycles:       100\ncapacity:            83.3%\ntime to empty:       4.0 hours'
out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["energyWh"]==40 and o["energyFullWh"]==50 and o["healthPercent"]==83
assert o["cycles"]==100 and abs(o["voltage"]-12.1)<0.01
assert o["timeEmptySeconds"]==14400 and o["timeFullSeconds"]==0
'; then
    ok "health energy cycles and remaining"
else
    err "stats: $out"
fi

export MODERN_BATTERY_TEXT=$'native-path:          BAT0\npercentage:          50%\nstate:               discharging\nenergy:              20.0 Wh\nenergy-full:         40.0 Wh\nenergy-rate:         10.0 W'
out="$("$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["onBattery"] and o["timeEmptySeconds"]==7200
'; then
    ok "estimates remaining from energy and rate"
else
    err "estimate: $out"
fi

if grep -F 'Paths.script("battery-read.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Battery.qml" >/dev/null; then
    ok "Settings/bar battery is this script"
else
    err "Battery.qml must run battery-read.sh"
fi

if grep -F 'Battery.onBattery' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/battery/Widget.qml" >/dev/null; then
    err "bar widget must not hide while charging"
else
    ok "bar widget follows hasBattery"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-battery-read: ok\n'
