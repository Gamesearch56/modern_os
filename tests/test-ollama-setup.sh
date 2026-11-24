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
printf '%s\n' "$*" >>"$MODERN_OLLAMA_LOG"
EOF
chmod +x "$TMP/systemctl"
export MODERN_OLLAMA_LOG="$TMP/log"
: >"$TMP/log"
MODERN_OLLAMA_SYSTEMCTL="$TMP/systemctl" "$ENABLE"
if [ "$(cat "$TMP/log")" = $'unmask ollama.service\nenable --now ollama.service' ]; then
    ok "enable clears a mask and starts ollama.service"
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

INSTALL_SH="$ROOT/scripts/ollama-install.sh"
ACTIVATE="$ROOT/scripts/ollama-activate.sh"

if "$INSTALL_SH" extra >/dev/null 2>&1; then
    err "install accepted an argument"
else
    ok "install rejects arguments"
fi

got="$(OLLAMA_INSTALL_DRY=1 "$INSTALL_SH")"
if [ "$got" = "pacman -S --noconfirm --needed -- ollama" ]; then
    ok "install is fixed to the ollama package"
else
    err "install dry printed: $got"
fi

if "$ACTIVATE" extra >/dev/null 2>&1; then
    err "activate accepted an argument"
else
    ok "activate rejects arguments"
fi

got="$(OLLAMA_ACTIVATE_DRY=1 "$ACTIVATE")"
if [ "$got" = "pkexec ollama-enable.sh" ]; then
    ok "activate asks for the password dialog then starts the service"
else
    err "activate dry printed: $got"
fi

if grep -Fq 'ensure_polkit_agent' "$INSTALL_SH" \
    && grep -Fq 'ensure_polkit_agent' "$ACTIVATE" \
    && ! grep -Fq 'ollama-install.sh' "$SETUP" \
    && grep -Fq 'ollama-activate.sh' "$SETUP" \
    && grep -Fq 'ollama-pull.sh' "$SETUP" \
    && grep -Fq 'qwen3:4b' "$SETUP" \
    && grep -Fq 'JobOverlay' "$INSTALL" \
    && grep -Fq 'settings.ollama.installPackage' "$INSTALL" \
    && grep -Fq 'Store.showPackage("ollama")' "$INSTALL" \
    && ! grep -Fq 'step3Title' "$INSTALL" \
    && ! grep -Fq 'step1Cmd' "$INSTALL"; then
    ok "settings opens the store, then starts and downloads in a dialog"
else
    err "settings path still installs from the page or hides the download"
fi

SECTION="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/Section.qml"
if [ "$(grep -cF 'visible: root.ollamaDone' "$SECTION")" -ge 4 ] \
    && grep -Fq 'ollamaSetup.setupBusy' "$SECTION" \
    && grep -Fq 'Install {' "$SECTION"; then
    ok "model, search key, and options stay hidden until the model is installed"
else
    err "ollama options show before setup finishes"
fi

STORE="$ROOT/stow/shell/.config/quickshell/modern/Services/Store.qml"
AI="$ROOT/stow/shell/.config/quickshell/modern/Services/Ai.qml"
if grep -Fq 'Ai.packageGone()' "$STORE" \
    && grep -Fq 'function packageGone' "$AI" \
    && grep -Fq 'focusStep: Ai.installed ? 1 : 0' "$INSTALL"; then
    ok "removing ollama returns the guide to the first step"
else
    err "removing ollama leaves the guide on the download step"
fi

if grep -Fq 'ollama_quiet_pull' "$PULL" \
    && grep -Fq 'nice -n 19' "$ROOT/scripts/lib/ollama-quiet.sh" \
    && grep -Fq 'ionice -c 3' "$ROOT/scripts/lib/ollama-quiet.sh"; then
    ok "the setup download stays at a low priority"
else
    err "the setup download can still pin the desktop"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ollama-setup: ok\n'
