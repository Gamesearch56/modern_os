#!/usr/bin/env bash
# Unprivileged coverage for hypridle-apply.sh. Never starts hypridle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-hypridle-apply: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-hypridle-apply: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/hypridle-apply.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-hypridle-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-hypridle-apply: refusing protected home" >&2; exit 1 ;;
    esac
fi

export MODERN_CONFIG_JSON="$TMP/config.json"
export MODERN_HYPRIDLE_CONF="$TMP/hypridle.conf"
export MODERN_BRIGHTNESS_SH="$TMP/brightness.sh"
export MODERN_HYPRIDLE_LOCK_DIR="$TMP"

printf '%s\n' '#!/bin/sh' 'exit 0' >"$MODERN_BRIGHTNESS_SH"
chmod +x "$MODERN_BRIGHTNESS_SH"

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

cat >"$MODERN_CONFIG_JSON" <<'EOF'
{
  "general": {
    "idleTimings": {
      "dimSec": 7200,
      "screenOffSec": 7200,
      "lockSec": 7200,
      "suspendSec": 43200
    }
  }
}
EOF

"$SCRIPT" --no-restart
if grep -q 'timeout = 7200' "$MODERN_HYPRIDLE_CONF" \
    && [ "$(grep -c 'timeout = 7200' "$MODERN_HYPRIDLE_CONF")" -eq 3 ] \
    && grep -q 'timeout = 43200' "$MODERN_HYPRIDLE_CONF" \
    && grep -Fq "$MODERN_BRIGHTNESS_SH dim" "$MODERN_HYPRIDLE_CONF" \
    && grep -Fq 'qs -c modern ipc call session lock' "$MODERN_HYPRIDLE_CONF" \
    && grep -Fq 'hl.dsp.dpms' "$MODERN_HYPRIDLE_CONF"; then
    ok "writes idle timings from config.json"
else
    err "render: $(cat "$MODERN_HYPRIDLE_CONF")"
fi

printf '%s\n' '{"general":{}}' >"$MODERN_CONFIG_JSON"
"$SCRIPT" --no-restart
if grep -q 'timeout = 120' "$MODERN_HYPRIDLE_CONF" \
    && grep -q 'timeout = 300' "$MODERN_HYPRIDLE_CONF" \
    && grep -q 'timeout = 600' "$MODERN_HYPRIDLE_CONF" \
    && grep -q 'timeout = 1800' "$MODERN_HYPRIDLE_CONF"; then
    ok "missing keys use defaults"
else
    err "defaults: $(cat "$MODERN_HYPRIDLE_CONF")"
fi

cat >"$MODERN_CONFIG_JSON" <<'EOF'
{
  "general": {
    "idleTimings": {
      "dimSec": 0,
      "screenOffSec": 7200,
      "lockSec": 0,
      "suspendSec": 1800
    }
  }
}
EOF
"$SCRIPT" --no-restart
if ! grep -q 'brightness.sh dim' "$MODERN_HYPRIDLE_CONF" \
    && ! grep -q 'on-timeout = qs -c modern ipc call session lock' "$MODERN_HYPRIDLE_CONF" \
    && grep -q 'timeout = 7200' "$MODERN_HYPRIDLE_CONF" \
    && grep -q 'timeout = 1800' "$MODERN_HYPRIDLE_CONF" \
    && grep -q 'lock_cmd = qs -c modern ipc call session lock' "$MODERN_HYPRIDLE_CONF" \
    && [ "$(grep -c '^listener {' "$MODERN_HYPRIDLE_CONF")" -eq 2 ]; then
    ok "zero timeouts omit hypridle listeners"
else
    err "never: $(cat "$MODERN_HYPRIDLE_CONF")"
fi

if grep -F 'Paths.script("hypridle-apply.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/IdleDaemon.qml" >/dev/null \
    && grep -F 'hypridle-apply.sh' \
    "$ROOT/stow/hypr/.config/hypr/modules/autostart.lua" >/dev/null \
    && grep -F 'hypridle-apply.sh' "$ROOT/scripts/reload-ui.sh" >/dev/null \
    && grep -F 'property int generation' \
    "$ROOT/stow/shell/.config/quickshell/modern/Commons/Config.qml" >/dev/null; then
    ok "login, Settings reload, and UI reload apply from disk JSON"
else
    err "IdleDaemon/autostart/reload-ui/Config.generation must call hypridle-apply.sh"
fi

if grep -Fq 'inhibit_sleep = 3' "$MODERN_HYPRIDLE_CONF"; then
    ok "suspend waits for the session lock"
else
    err "hypridle.conf must set inhibit_sleep = 3"
fi

# shellcheck disable=SC2016
if grep -Fq 'hypridle >>"$LOG"' "$SCRIPT" && ! grep -Fq 'nohup hypridle >/dev/null' "$SCRIPT"; then
    ok "hypridle output goes to its log"
else
    err "hypridle-apply.sh must log hypridle instead of discarding it"
fi

if grep -Fq '8>&-' "$SCRIPT" && grep -Fq 'flock -w 2' "$SCRIPT"; then
    ok "apply lock is timed and not inherited by hypridle"
else
    err "hypridle-apply.sh must flock -w and close fd 8 before starting hypridle"
fi

if grep -F 'Paths.script("idle-inhibit.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/IdleInhibit.qml" >/dev/null; then
    ok "fullscreen/media inhibit uses ScreenSaver, not only logind"
else
    err "IdleInhibit.qml must run idle-inhibit.sh"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-hypridle-apply: ok\n'
