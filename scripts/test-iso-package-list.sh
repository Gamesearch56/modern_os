#!/usr/bin/env bash
# mkarchiso keeps leftover spaces after s/#.*// as the pacman target.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/iso-aur-repo.sh
source "$ROOT/scripts/lib/iso-aur-repo.sh"

FAIL=0
err() { printf 'test-iso-package-list: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-iso-package-list: ok %s\n' "$*"; }

TMP="$(mktemp)"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

printf '%s\n' \
    'hyprland' \
    'calamares                       # AUR — built into a local repo' \
    '# comment only' \
    'networkmanager' \
    'calamares' \
    >"$TMP"

iso_sanitize_package_list "$TMP"

got="$(cat "$TMP")"
expected="$(printf '%s\n' hyprland calamares networkmanager)"
if [ "$got" = "$expected" ]; then
    ok "strips inline comments, spaces, and duplicates"
else
    err "expected packed names, got: $(printf '%q' "$got")"
fi

if grep -q '[[:space:]]' "$TMP"; then
    err "sanitized list still has whitespace"
else
    ok "no leftover whitespace"
fi

[ "$FAIL" -eq 0 ]
