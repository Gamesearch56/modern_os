#!/usr/bin/env bash
# UPower dump → JSON for Services/Battery.qml. Fixture never calls upower.
set -euo pipefail

die() { printf 'battery-read: ERROR: %s\n' "$*" >&2; exit 1; }
[ "$#" -eq 0 ] || die "usage: battery-read.sh"

if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
    [ -n "${MODERN_BATTERY_TEXT:-}" ] || die "MODERN_BATTERY_TEXT missing"
    TEXT="${MODERN_BATTERY_TEXT}"
else
    command -v upower >/dev/null 2>&1 || { printf '%s\n' '{"hasBattery":false}'; exit 0; }
    # upower -e lists mice and headsets before the laptop pack, and that
    # order changes. Only a power-supply battery is the machine's own.
    TEXT=""
    while IFS= read -r dev; do
        [ -n "$dev" ] || continue
        info="$(LC_ALL=C upower -i "$dev" 2>/dev/null || true)"
        printf '%s\n' "$info" | grep -qi 'power supply:[[:space:]]*yes' || continue
        printf '%s\n' "$info" | grep -qi 'percentage:' || continue
        TEXT="$info"
        break
    done < <(LC_ALL=C upower -e 2>/dev/null | grep -F '/battery_' || true)
    if [ -z "$TEXT" ]; then
        printf '%s\n' '{"hasBattery":false}'
        exit 0
    fi
fi

python3 - "$TEXT" <<'PY'
import json, re, sys

t = sys.argv[1] if len(sys.argv) > 1 else ""
low = t.lower()
if "percentage:" not in low:
    print(json.dumps({"hasBattery": False}, separators=(",", ":")))
    raise SystemExit(0)

def dur(s):
    u = (s or "").strip().lower()
    if not u or "unknown" in u:
        return 0
    m = re.search(r"([0-9]+(?:\.[0-9]+)?)", u)
    if not m:
        return 0
    n = float(m.group(1))
    if "hour" in u:
        return int(round(n * 3600))
    if "minute" in u:
        return int(round(n * 60))
    if "second" in u:
        return int(round(n))
    return 0

def num(pat):
    m = re.search(pat, t, re.I)
    if not m:
        return 0.0
    try:
        return float(m.group(1))
    except ValueError:
        return 0.0

pct_m = re.search(r"percentage:\s*([0-9]+(?:\.[0-9]+)?)", t, re.I)
st_m = re.search(r"state:\s*(\S+)", t, re.I)
empty_m = re.search(r"time to empty:\s*(.+)", t, re.I)
full_m = re.search(r"time to full:\s*(.+)", t, re.I)
cyc_m = re.search(r"charge-cycles:\s*(\S+)", t, re.I)
tech_m = re.search(r"technology:\s*(.+)", t, re.I)
state = (st_m.group(1).lower() if st_m else "")
pct = int(round(float(pct_m.group(1)))) if pct_m else 0
pct = max(0, min(100, pct))
charging = state in ("charging", "fully-charged")
on_bat = state in ("discharging", "pending-charge", "pending-discharge", "empty")
if state == "fully-charged":
    on_bat = False
if not charging and not on_bat and pct < 100:
    on_bat = True
rate = num(r"energy-rate:\s*([0-9]+(?:\.[0-9]+)?)")
energy = num(r"(?<![-\w])energy:\s*([0-9]+(?:\.[0-9]+)?)")
energy_full = num(r"energy-full:(?!-design)\s*([0-9]+(?:\.[0-9]+)?)")
energy_design = num(r"energy-full-design:\s*([0-9]+(?:\.[0-9]+)?)")
voltage = num(r"voltage:\s*([0-9]+(?:\.[0-9]+)?)")
cap = num(r"capacity:\s*([0-9]+(?:\.[0-9]+)?)")
health = int(round(cap)) if cap > 0 else (
    int(round(100 * energy_full / energy_design)) if energy_design > 0 and energy_full > 0 else 0
)
cycles = -1
if cyc_m:
    raw = cyc_m.group(1).replace(",", "")
    try:
        cycles = int(float(raw))
    except ValueError:
        cycles = -1
tech = (tech_m.group(1).strip() if tech_m else "")
time_empty = dur(empty_m.group(1) if empty_m else "")
time_full = dur(full_m.group(1) if full_m else "")
cap_s = 36 * 3600
if time_empty <= 0 and on_bat and rate > 0 and energy > 0:
    est = int(round(energy / rate * 3600))
    time_empty = est if 0 < est <= cap_s else 0
if time_full <= 0 and charging and state != "fully-charged" and rate > 0 and energy_full > energy:
    est = int(round((energy_full - energy) / rate * 3600))
    time_full = est if 0 < est <= cap_s else 0
time_to_full = bool(charging and time_full > 0)
time_s = time_full if time_to_full else time_empty
print(json.dumps({
    "hasBattery": True,
    "percent": pct,
    "charging": charging,
    "onBattery": on_bat,
    "timeSeconds": time_s,
    "timeToFull": time_to_full,
    "timeEmptySeconds": time_empty,
    "timeFullSeconds": time_full,
    "rateWatts": rate,
    "energyWh": energy,
    "energyFullWh": energy_full,
    "energyDesignWh": energy_design,
    "healthPercent": max(0, min(100, health)),
    "voltage": voltage,
    "cycles": cycles,
    "technology": tech,
}, separators=(",", ":")))
PY
