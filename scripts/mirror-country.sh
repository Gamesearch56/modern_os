#!/usr/bin/env bash
# Print the Arch mirror country for this machine.
# A country code from the public IP is used when that country has
# mirrors. Germany (network.mirrorCountry) is only the fallback.
set -euo pipefail

fallback_name() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json" name="Germany"
    if [ -n "${MODERN_MIRROR_FALLBACK:-}" ]; then
        printf '%s\n' "$MODERN_MIRROR_FALLBACK"
        return 0
    fi
    if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
        name="$(jq -r '.network.mirrorCountry // "Germany"' "$cfg" 2>/dev/null || true)"
        [ -n "$name" ] && [ "$name" != null ] || name="Germany"
    fi
    printf '%s\n' "$name"
}

# reflector --list-countries: "Germany                DE   150"
match_code() {
    local want="$1" line name code
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*(.+)[[:space:]]+([A-Z]{2})[[:space:]]+[0-9]+[[:space:]]*$ ]] || continue
        name="${BASH_REMATCH[1]}"
        name="${name%"${name##*[![:space:]]}"}"
        code="${BASH_REMATCH[2]}"
        if [ "$code" = "$want" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    done
    return 1
}

match_name() {
    local want="$1" line name
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*(.+)[[:space:]]+([A-Z]{2})[[:space:]]+[0-9]+[[:space:]]*$ ]] || continue
        name="${BASH_REMATCH[1]}"
        name="${name%"${name##*[![:space:]]}"}"
        if [ "$name" = "$want" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    done
    return 1
}

geo=""
if [ -n "${MODERN_MIRROR_GEO_JSON:-}" ]; then
    geo="$MODERN_MIRROR_GEO_JSON"
elif command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    geo="$(curl -fsS --max-time 8 --retry 1 --retry-delay 1 "https://get.geojs.io/v1/ip/geo.json" 2>/dev/null || true)"
    if [ -z "$geo" ]; then
        geo="$(curl -fsS --max-time 8 --retry 1 --retry-delay 1 "https://ipinfo.io/json" 2>/dev/null || true)"
    fi
fi

code=""
if [ -n "$geo" ] && command -v jq >/dev/null 2>&1; then
    code="$(jq -r '.country_code // .country // empty' <<<"$geo" 2>/dev/null || true)"
fi
code="$(printf '%s' "$code" | tr '[:lower:]' '[:upper:]')"
[[ "$code" =~ ^[A-Z]{2}$ ]] || code=""

list=""
if [ -n "${MODERN_MIRROR_COUNTRIES:-}" ]; then
    list="$MODERN_MIRROR_COUNTRIES"
elif command -v reflector >/dev/null 2>&1; then
    list="$(reflector --list-countries 2>/dev/null || true)"
fi

if [ -n "$code" ] && [ -n "$list" ]; then
    found="$(printf '%s\n' "$list" | match_code "$code" || true)"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        exit 0
    fi
fi

fb="$(fallback_name)"
if [ -n "$list" ]; then
    found="$(printf '%s\n' "$list" | match_name "$fb" || true)"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        exit 0
    fi
    found="$(printf '%s\n' "$list" | match_code DE || true)"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        exit 0
    fi
fi
printf '%s\n' "$fb"
