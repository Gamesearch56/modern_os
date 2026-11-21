#!/usr/bin/env bash
# Unprivileged coverage for autologin-apply.sh backends. Never writes /etc.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-autologin-apply: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-autologin-apply: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/autologin-apply.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-autologin-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-autologin-apply: refusing protected home" >&2; exit 1 ;;
    esac
fi

export MODERN_AUTOLOGIN_GREETD="$TMP/greetd.toml"
export MODERN_AUTOLOGIN_GETTY="$TMP/getty/99-modern-autologin.conf"

if "$SCRIPT" enable 'bad user' >/dev/null 2>&1; then
    err "rejected spaces in the username"
else
    ok "rejects an invalid username"
fi

printf '%s\n' '#!/bin/sh' >"$TMP/desktop-session.sh"
chmod +x "$TMP/desktop-session.sh"
export MODERN_DESKTOP_SESSION="$TMP/desktop-session.sh"

MODERN_AUTOLOGIN_BACKEND=greetd MODERN_DESKTOP_SESSION="$TMP/missing.sh" "$SCRIPT" enable testdev
if grep -Fq 'command = "start-hyprland --no-nixgl"' "$MODERN_AUTOLOGIN_GREETD"; then
    ok "greetd autologin starts Hyprland directly when the session wrapper is missing"
else
    err "missing wrapper: $(cat "$MODERN_AUTOLOGIN_GREETD")"
fi

MODERN_AUTOLOGIN_BACKEND=greetd "$SCRIPT" enable testdev
if grep -q '\[initial_session\]' "$MODERN_AUTOLOGIN_GREETD" \
    && grep -q 'user = "testdev"' "$MODERN_AUTOLOGIN_GREETD" \
    && grep -q 'user = "greeter"' "$MODERN_AUTOLOGIN_GREETD" \
    && grep -Fq 'source_profile = false' "$MODERN_AUTOLOGIN_GREETD" \
    && grep -Fq -- 'command = "/usr/lib/modern/desktop-session.sh"' "$MODERN_AUTOLOGIN_GREETD"; then
    ok "greetd enable writes initial_session"
else
    err "greetd enable: $(cat "$MODERN_AUTOLOGIN_GREETD")"
fi

MODERN_AUTOLOGIN_BACKEND=greetd "$SCRIPT" disable testdev
if grep -q '\[default_session\]' "$MODERN_AUTOLOGIN_GREETD" \
    && ! grep -q '\[initial_session\]' "$MODERN_AUTOLOGIN_GREETD"; then
    ok "greetd disable drops initial_session"
else
    err "greetd disable: $(cat "$MODERN_AUTOLOGIN_GREETD")"
fi

MODERN_AUTOLOGIN_BACKEND=getty "$SCRIPT" enable testdev
if grep -q -- '--autologin testdev' "$MODERN_AUTOLOGIN_GETTY"; then
    ok "getty enable writes a drop-in"
else
    err "getty enable: $(cat "$MODERN_AUTOLOGIN_GETTY")"
fi

MODERN_AUTOLOGIN_BACKEND=getty "$SCRIPT" disable testdev
if [ ! -f "$MODERN_AUTOLOGIN_GETTY" ]; then
    ok "getty disable removes the drop-in"
else
    err "getty disable left $MODERN_AUTOLOGIN_GETTY"
fi

if [ "$(id -u)" -ne 0 ]; then
    unset MODERN_AUTOLOGIN_BACKEND
    if "$SCRIPT" enable testdev >/dev/null 2>&1; then
        err "unprivileged run without a backend must fail"
    else
        ok "refuses to guess paths when not root"
    fi
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-autologin-apply: ok\n'
