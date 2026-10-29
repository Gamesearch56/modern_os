#!/usr/bin/env bash
# Unprivileged coverage for weather-geocode.sh. Never hits the network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-weather-geocode: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-weather-geocode: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/weather-geocode.sh"
export MODERN_TEST_FIXTURE=1

if "$SCRIPT" >/dev/null 2>&1; then
    err "rejected missing argv"
else
    ok "rejects missing argv"
fi
if "$SCRIPT" a b >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

short="$("$SCRIPT" x)"
if [ "$short" = "[]" ]; then
    ok "short query is an empty list"
else
    err "short query: $short"
fi

out="$("$SCRIPT" Berlin)"
if printf '%s\n' "$out" | python3 -c 'import json,sys,re
rows=json.load(sys.stdin)
assert rows and rows[0]["titleValue"]
assert re.match(r"^-?[0-9]+(\.[0-9]+)?,-?[0-9]+(\.[0-9]+)?$", rows[0]["value"])
'; then
    ok "fixture rows are lat,lon plus a city label"
else
    err "fixture: $out"
fi

if grep -F 'geocoding-api.open-meteo.com' "$SCRIPT" >/dev/null \
    && grep -F 'Paths.script("weather-geocode.sh")' \
        "$ROOT/stow/shell/.config/quickshell/modern/Services/WeatherGeocode.qml" >/dev/null; then
    ok "Settings city search is Open-Meteo via this script"
else
    err "WeatherGeocode.qml must run weather-geocode.sh"
fi

FETCH="$ROOT/scripts/weather-fetch.sh"
if grep -F 'if [ "$MODE" = "auto" ]; then' "$FETCH" >/dev/null \
    && grep -F 'elif [[ "$MANUAL"' "$FETCH" >/dev/null; then
    ok "weather-fetch uses geolocation before a saved city"
else
    err "weather-fetch.sh must prefer locationMode auto over manualLocation"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-weather-geocode: ok\n'
