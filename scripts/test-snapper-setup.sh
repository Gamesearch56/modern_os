#!/usr/bin/env bash
# Unprivileged coverage for snapper-setup.sh. Never writes /etc.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-snapper-setup: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-snapper-setup: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/snapper-setup.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-snapper-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-snapper-setup: refusing protected home" >&2; exit 1 ;;
    esac
fi

export MODERN_SNAPPER_CONFIGS_DIR="$TMP/configs"
export MODERN_SNAPPER_CONF_D="$TMP/conf.d/snapper"
export MODERN_SNAPPER_TEMPLATE="$TMP/default"
export MODERN_SNAPPER_SNAPSHOTS="$TMP/snapshots"

printf '%s\n' \
    'SUBVOLUME="/"' \
    'TIMELINE_CREATE="yes"' \
    'ALLOW_GROUPS=""' \
    >"$MODERN_SNAPPER_TEMPLATE"
mkdir -p "$(dirname "$MODERN_SNAPPER_CONF_D")"
printf 'SNAPPER_CONFIGS=""\n' >"$MODERN_SNAPPER_CONF_D"
mkdir -p "$MODERN_SNAPPER_SNAPSHOTS"

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

"$SCRIPT"
if grep -q '^TIMELINE_CREATE="no"' "$MODERN_SNAPPER_CONFIGS_DIR/root" \
    && grep -q '^ALLOW_GROUPS="wheel"' "$MODERN_SNAPPER_CONFIGS_DIR/root" \
    && grep -q '^SNAPPER_CONFIGS="root"' "$MODERN_SNAPPER_CONF_D"; then
    ok "writes root config when snapshots dir exists"
else
    err "write: $(cat "$MODERN_SNAPPER_CONFIGS_DIR/root" 2>/dev/null || true) $(cat "$MODERN_SNAPPER_CONF_D")"
fi

"$SCRIPT"
if [ "$(grep -c '^SNAPPER_CONFIGS=' "$MODERN_SNAPPER_CONF_D")" -eq 1 ] \
    && grep -q '^SNAPPER_CONFIGS="root"' "$MODERN_SNAPPER_CONF_D"; then
    ok "second run is idempotent"
else
    err "idempotent: $(cat "$MODERN_SNAPPER_CONF_D")"
fi

if grep -F 'Paths.script("snapper-setup.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Snapshots.qml" >/dev/null \
    && grep -F -- '--csvout list-configs' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Snapshots.qml" >/dev/null; then
    ok "Settings setup is one pkexec of this script"
else
    err "Snapshots.qml must pkexec snapper-setup.sh and probe csv list-configs"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-snapper-setup: ok\n'
