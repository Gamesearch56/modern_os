#!/usr/bin/env bash
# Unprivileged coverage for snapper-gc.sh. Never talks to real snapper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-snapper-gc: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-snapper-gc: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/snapper-gc.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-snapper-gc-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-snapper-gc: refusing protected home" >&2; exit 1 ;;
    esac
fi

export MODERN_TEST_FIXTURE=1
export MODERN_SNAPPER_LIST="$TMP/list"
export MODERN_SNAPPER_DELETED="$TMP/deleted"

seed() {
    local n
    : >"$MODERN_SNAPPER_LIST"
    : >"$MODERN_SNAPPER_DELETED"
    printf '0\n' >>"$MODERN_SNAPPER_LIST"
    for n in "$@"; do
        printf '%s\n' "$n" >>"$MODERN_SNAPPER_LIST"
    done
}

if "$SCRIPT" >/dev/null 2>&1; then
    err "rejected missing argv"
else
    ok "rejects missing argv"
fi

if "$SCRIPT" prune 2 >/dev/null 2>&1; then
    err "rejected keep 2"
else
    ok "rejects keep below 3"
fi

if "$SCRIPT" prune 21 >/dev/null 2>&1; then
    err "rejected keep 21"
else
    ok "rejects keep above 20"
fi

seed 1 2 3 4 5 6 7 8 9 10 11 12
"$SCRIPT" prune 8
if [ "$(tr '\n' ' ' <"$MODERN_SNAPPER_DELETED")" = "1 2 3 4 " ] \
    && ! grep -qx 0 "$MODERN_SNAPPER_DELETED"; then
    ok "prune 8 of 12 deletes the oldest four"
else
    err "prune: $(cat "$MODERN_SNAPPER_DELETED")"
fi

seed 3 5 7
: >"$MODERN_SNAPPER_DELETED"
"$SCRIPT" prune 8
if [ ! -s "$MODERN_SNAPPER_DELETED" ]; then
    ok "prune is a no-op when under keep"
else
    err "under-keep deleted: $(cat "$MODERN_SNAPPER_DELETED")"
fi

seed 1 2 3
"$SCRIPT" clear
if [ "$(tr '\n' ' ' <"$MODERN_SNAPPER_DELETED")" = "1 2 3 " ] \
    && ! grep -qx 0 "$MODERN_SNAPPER_DELETED"; then
    ok "clear deletes every snapshot except 0"
else
    err "clear: $(cat "$MODERN_SNAPPER_DELETED")"
fi

seed 1 2 3 4 5 6 7 8
"$SCRIPT" create Manual 8
if grep -qx 9 "$MODERN_SNAPPER_LIST" \
    && [ "$(tr '\n' ' ' <"$MODERN_SNAPPER_DELETED")" = "1 " ]; then
    ok "create then prune keeps the newest 8"
else
    err "create: list=$(cat "$MODERN_SNAPPER_LIST") del=$(cat "$MODERN_SNAPPER_DELETED")"
fi

printf '%s\n' '{"backup":{"pruneEnabled":false,"keepCount":3}}' >"$TMP/off.json"
seed 1 2 3 4 5
: >"$MODERN_SNAPPER_DELETED"
"$SCRIPT" prune-from-config "$TMP/off.json"
if [ ! -s "$MODERN_SNAPPER_DELETED" ]; then
    ok "prune-from-config honors pruneEnabled false"
else
    err "disabled prune deleted: $(cat "$MODERN_SNAPPER_DELETED")"
fi

printf '%s\n' '{"backup":{"pruneEnabled":true,"keepCount":5}}' >"$TMP/on.json"
seed 1 2 3 4 5 6 7
"$SCRIPT" prune-from-config "$TMP/on.json"
if [ "$(tr '\n' ' ' <"$MODERN_SNAPPER_DELETED")" = "1 2 " ]; then
    ok "prune-from-config uses keepCount"
else
    err "from-config: $(cat "$MODERN_SNAPPER_DELETED")"
fi

if grep -F 'Paths.script("snapper-gc.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Snapshots.qml" >/dev/null \
    && grep -F 'prune-from-config' "$ROOT/scripts/update-apply.sh" >/dev/null \
    && grep -F 'prune-from-config' "$ROOT/scripts/lib/modern-update.sh" >/dev/null; then
    ok "Settings and modern update call this script"
else
    err "Snapshots.qml / update-apply / modern-update must call snapper-gc.sh"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-snapper-gc: ok\n'
