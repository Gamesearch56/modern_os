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

# A mouse listed before BAT0 must not hide the laptop pack, and a
# desktop with only a peripheral battery stays empty.
updir="$(mktemp -d "${TMPDIR:-/tmp}/modern-upower-XXXXXX")"
cat >"$updir/upower" <<'EOF'
#!/bin/bash
set -eu
if [ "$1" = "-e" ]; then
    printf '%s\n' "$MODERN_FAKE_UPOWER_ENUM"
    exit 0
fi
if [ "$1" = "-i" ]; then
    case "$2" in
        *hidpp*) printf '%s\n' '  power supply:         no' '  percentage:          10%' ;;
        *BAT0*) printf '%s\n' '  power supply:         yes' '  percentage:          77%' '  state:               discharging' ;;
        *) exit 0 ;;
    esac
    exit 0
fi
exit 1
EOF
chmod +x "$updir/upower"
empty_supply="$(mktemp -d "${TMPDIR:-/tmp}/modern-supply-XXXXXX")"
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$empty_supply" \
    MODERN_FAKE_UPOWER_ENUM=$'/org/freedesktop/UPower/devices/battery_hidpp_battery_0\n/org/freedesktop/UPower/devices/battery_BAT0' \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["hasBattery"] and o["percent"]==77 and o["onBattery"]
'; then
    ok "laptop pack wins over a peripheral listed first"
else
    err "peripheral masked the laptop pack: $out"
fi
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$empty_supply" \
    MODERN_FAKE_UPOWER_ENUM=$'/org/freedesktop/UPower/devices/line_power_AC\n/org/freedesktop/UPower/devices/battery_hidpp_battery_0' \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
assert json.load(sys.stdin)=={"hasBattery":False}
'; then
    ok "desktop with a mouse battery is not a laptop pack"
else
    err "desktop should stay empty: $out"
fi
# UPower says this pack does not power the system. The kernel still
# lists it as the machine battery, so the bar icon has to stay.
pack="$(mktemp -d "${TMPDIR:-/tmp}/modern-pack-XXXXXX")"
install -d "$pack/BAT0"
printf 'Battery\n' >"$pack/BAT0/type"
printf '64\n' >"$pack/BAT0/capacity"
printf 'Discharging\n' >"$pack/BAT0/status"
cat >"$updir/upower" <<'EOF'
#!/bin/bash
set -eu
if [ "$1" = "-e" ]; then
    printf '%s\n' '/org/freedesktop/UPower/devices/battery_BAT0'
    exit 0
fi
if [ "$1" = "-i" ]; then
    printf '%s\n' '  power supply:         no' '  percentage:          64%' '  state:               discharging'
    exit 0
fi
exit 1
EOF
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$pack" \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["hasBattery"] and o["percent"]==64 and o["onBattery"]
'; then
    ok "kernel pack shows even when UPower clears power supply"
else
    err "kernel pack was hidden: $out"
fi

# UPower says the remaining time is unknown and the rate is 0. The
# kernel still has the seconds the status line shows.
cat >"$updir/upower" <<'EOF'
#!/bin/bash
set -eu
if [ "$1" = "-e" ]; then
    printf '%s\n' '/org/freedesktop/UPower/devices/battery_BAT0'
    exit 0
fi
if [ "$1" = "-i" ]; then
    printf '%s\n' \
        '  power supply:         no' \
        '  percentage:          64%' \
        '  state:               discharging' \
        '  time to empty:       unknown' \
        '  energy-rate:         0 W'
    exit 0
fi
exit 1
EOF
printf '7200\n' >"$pack/BAT0/time_to_empty_now"
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$pack" \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["timeEmptySeconds"]==7200 and o["onBattery"]
'; then
    ok "kernel time_to_empty_now fills remaining time"
else
    err "remaining time stayed empty: $out"
fi
rm -f "$pack/BAT0/time_to_empty_now"
printf '20000000\n' >"$pack/BAT0/energy_now"
printf '10000000\n' >"$pack/BAT0/power_now"
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$pack" \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["timeEmptySeconds"]==7200
'; then
    ok "energy and power estimate remaining time"
else
    err "energy estimate missed: $out"
fi

# upower has no devices: capacity from sysfs is enough for the icon.
cat >"$updir/upower" <<'EOF'
#!/bin/bash
exit 0
EOF
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$pack" \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
assert o["hasBattery"] and o["percent"]==64 and o["onBattery"]
'; then
    ok "sysfs capacity shows the icon without upower"
else
    err "sysfs pack was hidden: $out"
fi

mouse="$(mktemp -d "${TMPDIR:-/tmp}/modern-mouse-XXXXXX")"
install -d "$mouse/hidpp_battery_0"
printf 'Battery\n' >"$mouse/hidpp_battery_0/type"
printf 'Device\n' >"$mouse/hidpp_battery_0/scope"
printf '10\n' >"$mouse/hidpp_battery_0/capacity"
out="$(env -u MODERN_TEST_FIXTURE PATH="$updir:$PATH" \
    MODERN_POWER_SUPPLY_ROOT="$mouse" \
    "$SCRIPT")"
if printf '%s\n' "$out" | python3 -c 'import json,sys
assert json.load(sys.stdin)=={"hasBattery":False}
'; then
    ok "a mouse battery in sysfs stays hidden"
else
    err "mouse battery looked like a laptop pack: $out"
fi
rm -rf "$updir" "$empty_supply" "$pack" "$mouse"

if grep -F 'Paths.script("battery-read.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Battery.qml" >/dev/null; then
    ok "Settings/bar battery is this script"
else
    err "Battery.qml must run battery-read.sh"
fi

if grep -F 'Battery.onBattery' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/battery/Widget.qml" >/dev/null; then
    err "bar widget must not hide while charging"
elif grep -F 'visible: Battery.hasBattery' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/battery/Widget.qml" >/dev/null \
    && grep -F 'implicitWidth: Battery.hasBattery' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/battery/Widget.qml" >/dev/null \
    && grep -F 'clip: true' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/battery/Widget.qml" >/dev/null \
    && ! grep -F 'root.item.visible' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/WidgetLoader.qml" >/dev/null; then
    ok "bar widget follows hasBattery"
else
    err "bar widget must clip and follow hasBattery"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-battery-read: ok\n'
