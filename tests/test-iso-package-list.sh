#!/usr/bin/env bash
# mkarchiso keeps leftover spaces after s/#.*// as the pacman target.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib/iso-aur-repo.sh
source "$ROOT/scripts/lib/iso-aur-repo.sh"

FAIL=0
err() { printf 'test-iso-package-list: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-iso-package-list: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
log() { printf 'iso-build: %s\n' "$*" >&2; }

printf '%s\n' \
    'hyprland' \
    'calamares                       # AUR — built into a local repo' \
    '# comment only' \
    'networkmanager' \
    'calamares' \
    >"$TMP/list"

iso_sanitize_package_list "$TMP/list"

got="$(cat "$TMP/list")"
expected="$(printf '%s\n' hyprland calamares networkmanager)"
if [ "$got" = "$expected" ]; then
    ok "strips inline comments, spaces, and duplicates"
else
    err "expected packed names, got: $(printf '%q' "$got")"
fi

if grep -q '[[:space:]]' "$TMP/list"; then
    err "sanitized list still has whitespace"
else
    ok "no leftover whitespace"
fi

mkdir -p "$TMP/repo" "$TMP/cache"
printf 'new-bytes\n' >"$TMP/repo/yay-bin-13.1.0-1-x86_64.pkg.tar.zst"
printf 'old-bytes\n' >"$TMP/cache/yay-bin-13.1.0-1-x86_64.pkg.tar.zst"
printf 'sig\n' >"$TMP/cache/yay-bin-13.1.0-1-x86_64.pkg.tar.zst.sig"
printf 'same\n' >"$TMP/repo/matugen-bin-4.2.0-1-x86_64.pkg.tar.zst"
cp "$TMP/repo/matugen-bin-4.2.0-1-x86_64.pkg.tar.zst" \
    "$TMP/cache/matugen-bin-4.2.0-1-x86_64.pkg.tar.zst"
ISO_PKG_CACHE="$TMP/cache" iso_drop_stale_pkg_cache "$TMP/repo"
if [ "$(cat "$TMP/cache/yay-bin-13.1.0-1-x86_64.pkg.tar.zst")" = "new-bytes" ] \
    && [ ! -e "$TMP/cache/yay-bin-13.1.0-1-x86_64.pkg.tar.zst.sig" ] \
    && [ "$(cat "$TMP/cache/matugen-bin-4.2.0-1-x86_64.pkg.tar.zst")" = "same" ]; then
    ok "a stale cached package is replaced and a matching one is kept"
else
    err "stale package cache was not repaired"
fi

[ "$FAIL" -eq 0 ]
