#!/usr/bin/env bash
# Shared wallpaper seed cache. No matugen, no image decode.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-theme-seed: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-theme-seed: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-theme-seed-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export STATE_DIR="$TMP/state" THEME_SEED_VERSION="test"
# shellcheck source=lib/theme-seed.sh
source "$ROOT/scripts/lib/theme-seed.sh"

img="$TMP/wall.png"
printf 'x' >"$img"
theme_store_seed "$img" "#b42828"
got="$(theme_cached_seed "$img" || true)"
if [ "$got" = "#b42828" ]; then
    ok "stores and reads a seed for the same file"
else
    err "cache returned: ${got:-<empty>}"
fi

printf 'y' >>"$img"
got="$(theme_cached_seed "$img" || true)"
if [ -z "$got" ]; then
    ok "a changed file is not reused"
else
    err "changed file still returned $got"
fi

if grep -Fq 'theme_cached_seed' "$ROOT/scripts/theme-previews.sh" \
    && grep -Fq 'theme-seed.sh' "$ROOT/scripts/theme-apply.sh" \
    && grep -Fq 'theme-seed.sh' "$ROOT/scripts/theme-previews.sh"; then
    ok "light/dark previews share the apply cache"
else
    err "theme-previews does not use the shared seed cache"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-theme-seed: ok\n'
