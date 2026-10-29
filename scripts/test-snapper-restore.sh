#!/usr/bin/env bash
# Unprivileged coverage for snapper-restore.sh. Never mounts a real btrfs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-snapper-restore: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-snapper-restore: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/snapper-restore.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-snapper-restore-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-snapper-restore: refusing protected home" >&2; exit 1 ;;
    esac
fi

export MODERN_TEST_FIXTURE=1
export MODERN_RESTORE_ROOT="$TMP/btrfs"

seed() {
    local n="$1"
    rm -rf "$MODERN_RESTORE_ROOT"
    mkdir -p "$MODERN_RESTORE_ROOT/@/etc" \
        "$MODERN_RESTORE_ROOT/@home/user" \
        "$MODERN_RESTORE_ROOT/@snapshots/$n/snapshot/etc"
    printf 'old\n' >"$MODERN_RESTORE_ROOT/@/etc/os"
    printf 'stay\n' >"$MODERN_RESTORE_ROOT/@home/user/keep"
    printf 'new\n' >"$MODERN_RESTORE_ROOT/@snapshots/$n/snapshot/etc/os"
    printf '<snapshot><num>%s</num></snapshot>\n' "$n" \
        >"$MODERN_RESTORE_ROOT/@snapshots/$n/info.xml"
}

if "$SCRIPT" >/dev/null 2>&1; then
    err "rejected missing argv"
else
    ok "rejects missing argv"
fi

if "$SCRIPT" 0 >/dev/null 2>&1; then
    err "rejected snapshot 0"
else
    ok "rejects snapshot 0"
fi

if "$SCRIPT" 7 extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

seed 7
if "$SCRIPT" 9 >/dev/null 2>&1; then
    err "rejected missing snapshot"
else
    ok "rejects a missing snapshot"
fi

seed 7
"$SCRIPT" 7
old="$(find "$MODERN_RESTORE_ROOT" -maxdepth 1 -type d -name '@rollback-*' | head -n1)"
if [ "$(cat "$MODERN_RESTORE_ROOT/@/etc/os")" = new ] \
    && [ "$(cat "$MODERN_RESTORE_ROOT/@home/user/keep")" = stay ] \
    && [ -n "$old" ] && [ "$(cat "$old/etc/os")" = old ] \
    && [ ! -e "$MODERN_RESTORE_ROOT/@.restore-new" ]; then
    ok "replaces @, keeps @home, keeps the previous @"
else
    err "restore layout: $(find "$MODERN_RESTORE_ROOT" -maxdepth 3 | sort)"
fi

if grep -F 'Paths.script("snapper-restore.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Snapshots.qml" >/dev/null; then
    ok "Settings restore is one pkexec of this script"
else
    err "Snapshots.qml must pkexec snapper-restore.sh"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-snapper-restore: ok\n'
