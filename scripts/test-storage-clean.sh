#!/usr/bin/env bash
# Unprivileged coverage for storage-clean.sh. Never touches the live disk.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-storage-clean: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-storage-clean: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/storage-clean.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-storage-clean-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-storage-clean: refusing protected home" >&2; exit 1 ;;
    esac
fi

HOME_FAKE="$TMP/home"
PKG_FAKE="$TMP/pkg"
mkdir -p \
    "$HOME_FAKE/.cache/thumbnails/large" \
    "$HOME_FAKE/.cache/fontconfig" \
    "$HOME_FAKE/Documents" \
    "$PKG_FAKE"
printf 'thumb' >"$HOME_FAKE/.cache/thumbnails/large/a.png"
printf 'font' >"$HOME_FAKE/.cache/fontconfig/x"
printf 'keep' >"$HOME_FAKE/Documents/keep.txt"
printf 'oldpkg' >"$PKG_FAKE/foo-1-1-x86_64.pkg.tar.zst"

export MODERN_TEST_FIXTURE=1
export MODERN_CLEAN_HOME="$HOME_FAKE"
export MODERN_CLEAN_PKG="$PKG_FAKE"

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

out="$("$SCRIPT")"
if printf '%s\n' "$out" | grep -Eq '^done [0-9]+$' \
    && [ ! -e "$HOME_FAKE/.cache/thumbnails/large/a.png" ] \
    && [ ! -e "$HOME_FAKE/.cache/fontconfig/x" ] \
    && [ ! -e "$PKG_FAKE/foo-1-1-x86_64.pkg.tar.zst" ] \
    && [ "$(cat "$HOME_FAKE/Documents/keep.txt")" = keep ]; then
    ok "wipes allowlisted caches and leaves documents"
else
    err "clean: out=$out docs=$(cat "$HOME_FAKE/Documents/keep.txt" 2>/dev/null)"
fi

mkdir -p "$TMP/evil" "$HOME_FAKE/.cache"
ln -s "$TMP/evil" "$HOME_FAKE/.cache/thumbnails"
printf 'nope' >"$TMP/evil/x"
out="$("$SCRIPT" || true)"
if [ -f "$TMP/evil/x" ]; then
    ok "skips a cache dir that is a symlink"
else
    err "followed symlink"
fi

if grep -F 'Paths.script("storage-clean.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/StorageClean.qml" >/dev/null; then
    ok "Settings cleanup is one pkexec of this script"
else
    err "StorageClean.qml must pkexec storage-clean.sh"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-storage-clean: ok\n'
