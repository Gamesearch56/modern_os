#!/usr/bin/env bash
# Count installs per release. A release clone tells the counter its
# random id and its version, once a day. Nothing else is sent: no
# name, no account, no address. An empty census.url sends nothing.
#
#   census.sh note     used by desktop-sync on a release clone
#   census.sh counts   ask for the read secret, then print the totals
set -euo pipefail

TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
ID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
ID_FILE="$STATE/install-id"
STAMP="$STATE/census-day"
CFG="${MODERN_CENSUS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"

# Prints one https address. Exit 0 when it is usable, 1 when this file
# refuses it (empty on purpose, or not https), 2 when the file has no
# census.url. An update does not rewrite config.json, so a machine
# installed earlier has no key; that is not the same as opting out.
census_field() {
    local file="$1" url=""
    [ -f "$file" ] || return 2
    url="$(jq -r 'if (.census | type) == "object" and (.census | has("url")) then .census.url else "__MISSING__" end' "$file" 2>/dev/null)" || return 2
    [ "$url" = "__MISSING__" ] && return 2
    case "$url" in
        https://*@*|http://*|https://|*" "*|"") return 1 ;;
        https://*) printf '%s\n' "$url" ;;
        *) return 1 ;;
    esac
}

# The switch starts on. An explicit false is the opt-out. A settings
# file that never recorded the key follows that default.
census_on() {
    [ -f "$CFG" ] || return 1
    local flag
    flag="$(jq -r 'if (.census | type) == "object" and (.census | has("enabled")) then (if .census.enabled == true then "on" else "off" end) else "default" end' "$CFG" 2>/dev/null)" || return 1
    [ "$flag" != "off" ]
}

census_url() {
    local url="" rc=0
    url="$(census_field "$CFG")" || rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '%s\n' "$url"
        return 0
    fi
    # A set address that is empty or not https stays out. Only a missing
    # key falls through to the address shipped with this release.
    [ "$rc" -eq 2 ] || return 1
    url="$(census_field "$(dirname "$CFG")/config.default.json")" || return 1
    printf '%s\n' "$url"
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
    census_on || return 0
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

read_token() {
    local token="${CENSUS_READ_TOKEN:-}"
    if [ -n "$token" ]; then
        printf '%s' "$token"
        return 0
    fi
    [ -r /dev/tty ] || {
        printf 'census: set CENSUS_READ_TOKEN\n' >&2
        return 1
    }
    printf 'Census secret: ' >/dev/tty
    IFS= read -rs token </dev/tty || true
    printf '\n' >/dev/tty
    [ -n "$token" ] || {
        printf 'census: the secret was empty\n' >&2
        return 1
    }
    printf '%s' "$token"
}

show_counts() {
    python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.stderr.write("census: the counter did not return a count\n")
    sys.exit(1)
days = data.get("days", 30)
versions = data.get("versions") or {}
def key(name):
    parts = str(name).lstrip("v").split(".")
    return tuple(int(p) if p.isdigit() else 0 for p in parts)
rows = sorted(versions.items(), key=lambda item: key(item[0]), reverse=True)
print("Installs in the last %s days" % days)
print()
if not rows:
    print("  no machines have checked in")
    raise SystemExit
width = max(len(str(name)) for name, _ in rows + [("total", 0)])
total = 0
for name, count in rows:
    total += int(count)
    print("  %-*s  %s" % (width, name, count))
print("  %-*s  %s" % (width, "total", total))
'
}

cmd_counts() {
    local url token header body
    url="$(census_url)" || {
        printf 'census: set census.url to the counter address\n' >&2
        return 1
    }
    token="$(read_token)" || return 1
    header="$(mktemp "${TMPDIR:-/tmp}/modern-census-XXXXXX")"
    chmod 600 "$header"
    trap 'rm -f "$header"' RETURN
    printf 'header = "Authorization: Bearer %s"\n' "$token" >"$header"
    body="$(curl --proto '=https' --tlsv1.2 -fsS --max-time 20 \
        --config "$header" "$url")" || return 1
    printf '%s' "$body" | show_counts
}

case "${1:-}" in
    note) cmd_note ;;
    counts) cmd_counts ;;
    *) printf 'usage: census.sh note|counts\n' >&2; exit 2 ;;
esac
