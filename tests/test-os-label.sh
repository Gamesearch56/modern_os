#!/usr/bin/env bash
# Kitty's OS line uses the same words as Settings → Overview.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-os-label: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-os-label: ok %s\n' "$*"; }

LABEL="$ROOT/scripts/os-label.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-os-label-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

git -C "$TMP" init -q -b main
git -C "$TMP" -c user.email=t@example.com -c user.name=test commit -q --allow-empty -m init
git -C "$TMP" tag v9.9.9

write_cfg() {
    local lang="$1"
    mkdir -p "$TMP/cfg/modern"
    printf '%s\n' "$TMP" >"$TMP/cfg/modern/repo"
    printf '{ "language": { "ui": "%s" } }\n' "$lang" >"$TMP/cfg/modern/config.json"
}

write_cfg en
got="$(XDG_CONFIG_HOME="$TMP/cfg" "$LABEL")"
if [ "$got" = "ModernOS v9.9.9 (Arch Linux)" ]; then
    ok "a release tag matches the overview"
else
    err "release label: $got"
fi

write_cfg de
got="$(XDG_CONFIG_HOME="$TMP/cfg" "$LABEL")"
if [ "$got" = "ModernOS v9.9.9 (Arch Linux)" ]; then
    ok "the German release line matches the overview"
else
    err "german release label: $got"
fi

git -C "$TMP" -c user.email=t@example.com -c user.name=test commit -q --allow-empty -m later
short="$(git -C "$TMP" rev-parse --short HEAD)"
write_cfg en
got="$(XDG_CONFIG_HOME="$TMP/cfg" "$LABEL")"
if [ "$got" = "ModernOS v9.9.9, development build $short (Arch Linux)" ]; then
    ok "a build between releases names the last version and the commit"
else
    err "dev label: $got"
fi
write_cfg de
got="$(XDG_CONFIG_HOME="$TMP/cfg" "$LABEL")"
if [ "$got" = "ModernOS v9.9.9, Entwicklungsstand $short (Arch Linux)" ]; then
    ok "the German development line matches the overview"
else
    err "german dev label: $got"
fi

rm -f "$TMP/cfg/modern/repo"
got="$(XDG_CONFIG_HOME="$TMP/cfg" "$LABEL")"
if [ "$got" = "ModernOS (Arch Linux)" ]; then
    ok "without a checkout the name stays ModernOS"
else
    err "fallback label: $got"
fi

if grep -Fq 'os-label.sh' "$ROOT/stow/theme/.config/matugen/templates/fastfetch.jsonc.template" \
    && ! grep -Fq '"os"' "$ROOT/stow/theme/.config/matugen/templates/fastfetch.jsonc.template"; then
    ok "fastfetch asks for the overview OS line"
else
    err "fastfetch still prints the distribution name"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-os-label: ok\n'
