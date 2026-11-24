#!/usr/bin/env bash
# Count installs per release. A release clone tells the counter its
# random id and its version, once a day. Nothing else is sent: no
# name, no account, no address. An empty census.url sends nothing.
#
#   census.sh note     used by desktop-sync on a release clone
#   census.sh counts   print the totals (needs CENSUS_READ_TOKEN)
set -euo pipefail

TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
ID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
ID_FILE="$STATE/install-id"
STAMP="$STATE/census-day"
CFG="${MODERN_CENSUS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"

census_url() {
    local url=""
    if [ -f "$CFG" ]; then
        url="$(jq -r '.census.url // empty' "$CFG" 2>/dev/null || true)"
    fi
    # https only, and no password embedded in the address.
    case "$url" in
        https://*@*|http://*|https://|*" "*|"") return 1 ;;
        https://*) printf '%s\n' "$url" ;;
        *) return 1 ;;
    esac
}

install_id() {
    local id=""
    if [ -f "$ID_FILE" ]; then
        id="$(head -n 1 "$ID_FILE" 2>/dev/null || true)"
    fi
    if [[ ! "$id" =~ $ID_RE ]]; then
        id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
        mkdir -p "$STATE"
        printf '%s\n' "$id" >"$ID_FILE"
        chmod 600 "$ID_FILE"
    fi
    printf '%s\n' "$id"
}

cmd_note() {
    [ "${MODERN_CENSUS_FORCE:-}" = "1" ] || [ "${MODERN_CENSUS_RELEASE:-}" = "1" ] || return 0
    local url version id today stamp body
    url="$(census_url)" || return 0
    version="${MODERN_CENSUS_VERSION:-}"
    [[ "$version" =~ $TAG_RE ]] || return 0
    today="$(date -u +%F)"
    stamp="$(head -n 1 "$STAMP" 2>/dev/null || true)"
    [ "$stamp" = "$today $version" ] && return 0
    id="$(install_id)"
    body="$(ID="$id" VER="$version" python3 -c 'import json,os; print(json.dumps({"id":os.environ["ID"],"version":os.environ["VER"]}))')"
    curl --proto '=https' --tlsv1.2 -fsS --max-time 5 \
        -H 'content-type: application/json' \
        --data "$body" "$url" >/dev/null
    mkdir -p "$STATE"
    printf '%s %s\n' "$today" "$version" >"$STAMP"
}

cmd_counts() {
    local url token
    url="$(census_url)" || {
        printf 'census: set census.url to the counter address\n' >&2
        return 1
    }
    token="${CENSUS_READ_TOKEN:-}"
    [ -n "$token" ] || {
        printf 'census: set CENSUS_READ_TOKEN\n' >&2
        return 1
    }
    curl --proto '=https' --tlsv1.2 -fsS --max-time 20 \
        -H "Authorization: Bearer $token" "$url"
    printf '\n'
}

case "${1:-}" in
    note) cmd_note ;;
    counts) cmd_counts ;;
    *) printf 'usage: census.sh note|counts\n' >&2; exit 2 ;;
esac
