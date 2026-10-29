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
    dev="$(LC_ALL=C upower -e 2>/dev/null | grep -Ei 'battery_|/BAT[0-9]' | head -1 || true)"
    if [ -z "$dev" ]; then
        printf '%s\n' '{"hasBattery":false}'
        exit 0
    fi
    TEXT="$(LC_ALL=C upower -i "$dev" 2>/dev/null || true)"
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

pct_m = re.search(r"percentage:\s*([0-9]+(?:\.[0-9]+)?)", t, re.I)
st_m = re.search(r"state:\s*(\S+)", t, re.I)
rate_m = re.search(r"energy-rate:\s*([0-9]+(?:\.[0-9]+)?)", t, re.I)
empty_m = re.search(r"time to empty:\s*(.+)", t, re.I)
full_m = re.search(r"time to full:\s*(.+)", t, re.I)
state = (st_m.group(1).lower() if st_m else "")
pct = int(round(float(pct_m.group(1)))) if pct_m else 0
pct = max(0, min(100, pct))
charging = state in ("charging", "fully-charged")
on_bat = state in ("discharging", "pending-charge", "pending-discharge", "empty")
if state == "fully-charged":
    on_bat = False
if not charging and not on_bat and pct < 100:
    on_bat = True
time_to_full = bool(charging and full_m)
time_s = dur(full_m.group(1) if time_to_full else (empty_m.group(1) if empty_m else ""))
print(json.dumps({
    "hasBattery": True,
    "percent": pct,
    "charging": charging,
    "onBattery": on_bat,
    "timeSeconds": time_s,
    "timeToFull": time_to_full,
    "rateWatts": float(rate_m.group(1)) if rate_m else 0,
}, separators=(",", ":")))
PY
