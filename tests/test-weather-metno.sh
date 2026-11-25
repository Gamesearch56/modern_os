#!/usr/bin/env bash
# weather-metno.py turns MET Norway's forecast into the Open-Meteo shape
# Services/Weather.qml parses. Never hits the network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-weather-metno: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-weather-metno: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/forecast.json" <<'EOF'
{"properties":{"timeseries":[
 {"time":"2026-06-21T10:00:00Z","data":{
  "instant":{"details":{"air_temperature":20.0,"apparent_air_temperature":19.0,"relative_humidity":50.0,"wind_speed":5.0,"air_pressure_at_sea_level":1015.0,"ultraviolet_index_clear_sky":6.0}},
  "next_1_hours":{"summary":{"symbol_code":"lightrainshowers_day"},"details":{"precipitation_amount":1.0}},
  "next_6_hours":{"summary":{"symbol_code":"rain"},"details":{"air_temperature_max":24.0,"air_temperature_min":18.0}}}},
 {"time":"2026-06-21T11:00:00Z","data":{
  "instant":{"details":{"air_temperature":22.0,"wind_speed":2.0}},
  "next_1_hours":{"summary":{"symbol_code":"partlycloudy_day"},"details":{}}}},
 {"time":"2026-06-22T12:00:00Z","data":{
  "instant":{"details":{"air_temperature":15.0,"wind_speed":1.0}},
  "next_6_hours":{"summary":{"symbol_code":"heavysnow"},"details":{}}}}
]}}
EOF

check() {
    TZ=UTC python3 "$ROOT/scripts/weather-metno.py" "$TMP/forecast.json" 49.49 8.47 "$1" \
        | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if ($2) else 1)"
}

if check metric 'd["current"]["temperature_2m"] == 20.0 and d["current"]["wind_speed_10m"] == 18.0 and d["current"]["weather_code"] == 80 and d["current"]["is_day"] == 1'; then
    ok "current conditions come from the first entry (km/h, WMO code)"
else
    err "current conditions are wrong"
fi
if check metric 'd["daily"]["time"] == ["2026-06-21", "2026-06-22"] and d["daily"]["temperature_2m_max"][0] == 24.0 and d["daily"]["weather_code"][1] == 75'; then
    ok "days group by local date with the 6-hour extremes"
else
    err "daily rows are wrong"
fi
if check metric 'len(d["hourly"]["time"]) == 2 and d["hourly"]["time"][0] == "2026-06-21T10:00"'; then
    ok "hourly rows are the entries that have a 1-hour forecast"
else
    err "hourly rows are wrong"
fi
if check metric 'd["daily"]["sunrise"][0].startswith("2026-06-21T03:") and d["daily"]["sunset"][0].startswith("2026-06-21T19:")'; then
    ok "sunrise and sunset are computed for the location"
else
    err "sunrise/sunset are wrong"
fi
if check imperial 'd["current"]["temperature_2m"] == 68.0 and d["current"]["wind_speed_10m"] == 11.2'; then
    ok "imperial converts to Fahrenheit and mph"
else
    err "imperial units are wrong"
fi

grep -F 'weather-metno.py' "$ROOT/scripts/weather-fetch.sh" >/dev/null \
    || err "weather-fetch.sh must fall back to weather-metno.py"

if [ "$FAIL" -eq 0 ]; then
    ok "done"
else
    exit 1
fi
