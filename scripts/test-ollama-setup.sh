#!/usr/bin/env bash
# Enable is a fixed systemctl. The pull is a fixed small model and
# never takes a name from the caller. No pkexec, no network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-ollama-setup: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-ollama-setup: ok %s\n' "$*"; }

ENABLE="$ROOT/scripts/ollama-enable.sh"
PULL="$ROOT/scripts/ollama-pull.sh"
SETUP="$ROOT/stow/shell/.config/quickshell/modern/Services/AiStatus.qml"
INSTALL="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/Install.qml"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-ollama-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

if "$ENABLE" extra >/dev/null 2>&1; then
    err "enable accepted an argument"
else
    ok "enable rejects arguments"
fi

if "$ENABLE" >/dev/null 2>&1; then
    err "enable ran without root"
else
    ok "enable refuses to start the unit when not root"
fi

cat >"$TMP/systemctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$MODERN_OLLAMA_LOG"
EOF
chmod +x "$TMP/systemctl"
export MODERN_OLLAMA_LOG="$TMP/log"
MODERN_OLLAMA_SYSTEMCTL="$TMP/systemctl" "$ENABLE"
if [ "$(cat "$TMP/log")" = "enable --now ollama.service" ]; then
    ok "enable starts ollama.service"
else
    err "enable command: $(cat "$TMP/log" 2>/dev/null)"
fi

if "$PULL" extra >/dev/null 2>&1; then
    err "pull accepted an argument"
else
    ok "pull rejects arguments"
fi

got="$(OLLAMA_PULL_DRY=1 "$PULL")"
if [ "$got" = "qwen3:4b" ]; then
    ok "pull is fixed to qwen3:4b"
else
    err "pull dry printed: $got"
fi

if grep -Fq 'pkexec' "$SETUP" \
    && grep -Fq 'ollama-enable.sh' "$SETUP" \
    && grep -Fq 'ollama-pull.sh' "$SETUP" \
    && grep -Fq 'qwen3:4b' "$SETUP" \
    && grep -Fq 'Store.showPackage("ollama")' "$INSTALL"; then
    ok "settings opens the store and runs both scripts"
else
    err "settings path does not open the store or run both scripts"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ollama-setup: ok\n'
