#!/usr/bin/env bash
# Open-Meteo city search for Settings weather. Prints
# [{value:"lat,lon",titleValue:"Name, Region, Country"}, ...]
# so weather-fetch.sh can use the value as coordinates. Fixture
# never hits the network.
set -euo pipefail

die() { printf 'weather-geocode: ERROR: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: weather-geocode.sh <query>"

Q="$1"
if [ "${#Q}" -lt 2 ]; then
    printf '[]\n'
    exit 0
fi

if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
    printf '%s\n' '[{"value":"52.52437,13.41053","titleValue":"Berlin, Land Berlin, Germany"}]'
    exit 0
fi

command -v curl >/dev/null 2>&1 || die "curl missing"
command -v jq >/dev/null 2>&1 || die "jq missing"

lang="${LANG:-en}"
lang="${lang%%_*}"
lang="${lang%%.*}"
[[ "$lang" =~ ^[a-z]{2}$ ]] || lang="en"

enc="$(jq -nr --arg s "$Q" '$s|@uri')"
geo="$(curl -fsS --max-time 8 --retry 1 \
    "https://geocoding-api.open-meteo.com/v1/search?name=${enc}&count=8&language=${lang}&format=json")"

jq -c '
  (.results // [])
  | map(select((.latitude != null) and (.longitude != null)))
  | map({
      value: ((.latitude | tostring) + "," + (.longitude | tostring)),
      titleValue: (
        [.name, .admin1, .country]
        | map(select(. != null and . != ""))
        | join(", ")
      )
    })
' <<<"$geo"
