#!/usr/bin/env bash
# Mirror country resolution and the two-week refresh. No network, no root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-mirrors: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-mirrors: ok %s\n' "$*"; }

COUNTRY="$ROOT/scripts/mirror-country.sh"
REFRESH="$ROOT/scripts/mirrors-refresh.sh"
LIST=$'Country              Code Count\n-------------------- ---- -----\nGermany                DE   150\nFrance                 FR    63\nUnited States          US    45\nHong Kong              HK    11\n'

pick() {
    MODERN_MIRROR_COUNTRIES="$LIST" MODERN_MIRROR_FALLBACK="${2:-Germany}" \
        MODERN_MIRROR_GEO_JSON="${1:-}" "$COUNTRY"
}

got="$(pick '{"country_code":"FR"}')"
if [ "$got" = France ]; then
    ok "a listed country code selects that country"
else
    err "FR resolved to: $got"
fi

got="$(pick '{"country":"us"}')"
if [ "$got" = "United States" ]; then
    ok "a lowercase code still matches the mirror name"
else
    err "us resolved to: $got"
fi

got="$(pick '{"country_code":"HK"}')"
if [ "$got" = "Hong Kong" ]; then
    ok "a two-word country name is kept"
else
    err "HK resolved to: $got"
fi

got="$(pick '{"country_code":"ZZ"}' France)"
if [ "$got" = France ]; then
    ok "an unknown code uses the configured fallback when it is listed"
else
    err "unknown code with France fallback: $got"
fi

got="$(pick '{"country_code":"ZZ"}' Narnia)"
if [ "$got" = Germany ]; then
    ok "an unlisted fallback lands on Germany"
else
    err "Narnia fallback: $got"
fi

got="$(pick '{}')"
if [ "$got" = Germany ]; then
    ok "no location uses Germany"
else
    err "empty location: $got"
fi

got="$(pick '{"country_code":"DE"}' France)"
if [ "$got" = Germany ]; then
    ok "a resolved location wins over the fallback"
else
    err "DE with France fallback: $got"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
now=1700000000
printf '%s\n' "$now" >"$TMP/stamp"
if MODERN_MIRROR_STAMP="$TMP/stamp" MODERN_MIRROR_NOW="$now" "$REFRESH" --due; then
    err "a fresh stamp must not be due"
else
    ok "a fresh stamp is not due"
fi
later=$((now + 13 * 24 * 60 * 60))
if MODERN_MIRROR_STAMP="$TMP/stamp" MODERN_MIRROR_NOW="$later" "$REFRESH" --due; then
    ok "a stamp older than twelve days is due"
else
    err "thirteen days was not due"
fi

if MODERN_MIRROR_STAMP="$TMP/stamp" MODERN_MIRROR_NOW="$now" \
    MODERN_MIRROR_FAKE="$TMP/ran" "$REFRESH" --auto; then
    if [ -e "$TMP/ran" ]; then
        err "a fresh stamp must not refresh"
    else
        ok "auto skips a fresh mirror list"
    fi
else
    err "auto on a fresh stamp failed"
fi

rm -f "$TMP/stamp" "$TMP/ran"
if MODERN_MIRROR_STAMP="$TMP/stamp" MODERN_MIRROR_NOW="$now" \
    MODERN_MIRROR_FAKE="$TMP/ran" MODERN_MIRROR_COUNTRIES="$LIST" \
    MODERN_MIRROR_GEO_JSON='{"country_code":"FR"}' \
    "$REFRESH" --auto && [ "$(cat "$TMP/ran")" = France ]; then
    ok "auto refresh uses the resolved country"
else
    err "auto refresh: $(cat "$TMP/ran" 2>/dev/null || true)"
fi

if MODERN_MIRROR_STAMP="$TMP/stamp" MODERN_MIRROR_FAKE="$TMP/bad" \
    "$REFRESH" --country '--Germany' >/dev/null 2>&1; then
    err "a country flag must be refused"
else
    ok "a country flag is refused"
fi

out="$(REPO_ROOT="$ROOT" DRY_RUN=1 bash -c 'source "$1"; mirrors_apply' _ "$ROOT/install/lib/mirrors.sh")"
if [ "$out" = "mirrors: would enable modern-mirrors.timer" ]; then
    ok "dry-run only reports the timer"
else
    err "dry-run: $out"
fi

if grep -F 'mirror-country.sh' "$ROOT/scripts/modern" >/dev/null \
    && grep -F 'mirrors-refresh.sh' "$ROOT/scripts/modern" >/dev/null \
    && ! grep -F 'cfg network.mirrorCountry' "$ROOT/scripts/modern" >/dev/null \
    && grep -F "printf 'mirrors\\n'" "$ROOT/install/install.sh" >/dev/null \
    && grep -F 'skipping mirror refresh (dotfiles-only)' "$ROOT/install/install.sh" >/dev/null \
    && grep -F 'mirrors_apply' "$ROOT/scripts/update-apply.sh" >/dev/null \
    && grep -F 'OnCalendar=*-*-1,15 05:00:00' \
        "$ROOT/install/system/mirrors/modern-mirrors.timer" >/dev/null \
    && grep -F 'Persistent=true' \
        "$ROOT/install/system/mirrors/modern-mirrors.timer" >/dev/null \
    && grep -F '/usr/local/lib/modern/mirrors-refresh.sh --auto' \
        "$ROOT/install/system/mirrors/modern-mirrors.service" >/dev/null \
    && grep -F -- '--protocol https' "$REFRESH" >/dev/null \
    && ! grep -F -- '--protocol rsync' "$REFRESH" >/dev/null; then
    ok "the button, the installer, and the timer share one refresh"
else
    err "mirror wiring is incomplete"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-mirrors: ok\n'
