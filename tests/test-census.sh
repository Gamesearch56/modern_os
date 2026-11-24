#!/usr/bin/env bash
# The install count sends a random id and a release, or nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CENSUS="$ROOT/scripts/census.sh"
FAIL=0
err() { printf 'test-census: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-census: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-census-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/state" "$TMP/cfg"
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$CENSUS_CURL_LOG"
if [ -n "${CENSUS_CURL_BODY:-}" ]; then
    printf '%s' "$CENSUS_CURL_BODY"
fi
exit 0
EOF
chmod +x "$TMP/bin/curl" "$CENSUS"

export PATH="$TMP/bin:$PATH"
export XDG_STATE_HOME="$TMP/state"
export XDG_CONFIG_HOME="$TMP/cfg"
export CENSUS_CURL_LOG="$TMP/curl.log"
export MODERN_CENSUS_FORCE=1
export MODERN_CENSUS_VERSION=v0.8.14
: >"$CENSUS_CURL_LOG"

printf '{}\n' >"$TMP/cfg/modern-empty.json"
MODERN_CENSUS_CONFIG="$TMP/cfg/modern-empty.json" "$CENSUS" note
if [ ! -s "$CENSUS_CURL_LOG" ] && [ ! -f "$TMP/state/modern/install-id" ]; then
    ok "an empty address sends nothing and creates no id"
else
    err "empty address still sent or created an id"
fi

printf '{"census":{"url":"http://counter.example/note"}}\n' >"$TMP/cfg/modern-http.json"
MODERN_CENSUS_CONFIG="$TMP/cfg/modern-http.json" "$CENSUS" note
if [ ! -s "$CENSUS_CURL_LOG" ]; then
    ok "a plain http address is refused"
else
    err "http was accepted"
fi

printf '{"census":{"url":"https://counter.example/note"}}\n' >"$TMP/cfg/modern-https.json"
MODERN_CENSUS_CONFIG="$TMP/cfg/modern-https.json" "$CENSUS" note
MODERN_CENSUS_CONFIG="$TMP/cfg/modern-https.json" "$CENSUS" note
id="$(head -n 1 "$TMP/state/modern/install-id")"
mode="$(stat -c '%a' "$TMP/state/modern/install-id")"
posts="$(wc -l <"$CENSUS_CURL_LOG" | tr -d ' ')"
if [[ "$id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] \
    && [ "$mode" = 600 ] && [ "$posts" = 1 ] \
    && grep -Fq -- "--data {\"id\": \"$id\", \"version\": \"v0.8.14\"}" "$CENSUS_CURL_LOG" \
    && grep -Fq 'https://counter.example/note' "$CENSUS_CURL_LOG"; then
    ok "one note a day carries the random id and the release"
else
    err "note: id=$id mode=$mode posts=$posts log=$(cat "$CENSUS_CURL_LOG")"
fi

export CENSUS_READ_TOKEN=secret
export CENSUS_CURL_BODY='{"days":30,"versions":{"v0.8.13":1,"v0.8.14":2}}'
shown="$(MODERN_CENSUS_CONFIG="$TMP/cfg/modern-https.json" "$CENSUS" counts)"
if printf '%s\n' "$shown" | grep -q 'Installs in the last 30 days' \
    && printf '%s\n' "$shown" | grep -q 'v0.8.14  2' \
    && printf '%s\n' "$shown" | grep -q 'total    3' \
    && ! printf '%s\n' "$shown" | grep -q 'secret'; then
    ok "counts lists each release and a total"
else
    err "counts printed: $shown"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-census: ok\n'
