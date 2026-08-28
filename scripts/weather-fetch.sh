#!/usr/bin/env bash
# Resolve lat/lon (manual city / lat,lon, or IP) and print Open-Meteo JSON
# for Services/Weather.qml. No API key.
set -euo pipefail

MODERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
DEFAULT_JSON="$MODERN_DIR/config.default.json"
LIVE_JSON="$MODERN_DIR/config.json"

merged() {
    if [ -f "$LIVE_JSON" ] && [ -f "$DEFAULT_JSON" ]; then
        jq -s '.[0] * .[1]' "$DEFAULT_JSON" "$LIVE_JSON"
    elif [ -f "$LIVE_JSON" ]; then
        cat "$LIVE_JSON"
    elif [ -f "$DEFAULT_JSON" ]; then
        cat "$DEFAULT_JSON"
    else
        echo '{}'
    fi
}

CFG="$(merged)"
MODE="$(jq -r '.widgets.weather.locationMode // "auto"' <<<"$CFG")"
MANUAL="$(jq -r '.widgets.weather.manualLocation // ""' <<<"$CFG")"
UNITS="$(jq -r '.widgets.weather.units // "metric"' <<<"$CFG")"
TEMP_UNIT="celsius"
if [ "$UNITS" = "imperial" ]; then
    TEMP_UNIT="fahrenheit"
fi

curl_json() {
    curl -fsS --max-time 8 "$1"
}

lat=""
lon=""

if [[ "$MANUAL" =~ ^[[:space:]]*(-?[0-9]+(\.[0-9]+)?)[[:space:]]*,[[:space:]]*(-?[0-9]+(\.[0-9]+)?)[[:space:]]*$ ]]; then
    lat="${BASH_REMATCH[1]}"
    lon="${BASH_REMATCH[3]}"
elif [ -n "$MANUAL" ]; then
    q="$(jq -nr --arg s "$MANUAL" '$s|@uri')"
    geo="$(curl_json "https://geocoding-api.open-meteo.com/v1/search?name=${q}&count=1")"
    lat="$(jq -r '.results[0].latitude // empty' <<<"$geo")"
    lon="$(jq -r '.results[0].longitude // empty' <<<"$geo")"
elif [ "$MODE" = "auto" ]; then
    ipjson="$(curl_json "https://get.geojs.io/v1/ip/geo.json" || true)"
    lat="$(jq -r '.latitude // empty' <<<"${ipjson:-}")"
    lon="$(jq -r '.longitude // empty' <<<"${ipjson:-}")"
    if [ -z "$lat" ] || [ -z "$lon" ]; then
        ipjson="$(curl_json "https://ipinfo.io/json" || true)"
        loc="$(jq -r '.loc // empty' <<<"${ipjson:-}")"
        lat="${loc%%,*}"
        lon="${loc#*,}"
    fi
fi

if [ -z "${lat:-}" ] || [ -z "${lon:-}" ] || [ "$lat" = "null" ] || [ "$lon" = "null" ]; then
    echo "weather-fetch: no coordinates (set widgets.weather.manualLocation or use locationMode auto)" >&2
    exit 1
fi

curl_json "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,is_day&temperature_unit=${TEMP_UNIT}"
