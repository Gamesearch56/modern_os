#!/usr/bin/env bash
# Autostart must spawn via Lua exec_cmd. Hyprland 0.56 rejects
# `hyprctl dispatch exec`, which left mail/chat never launched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-modern-launch: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-modern-launch: ok %s\n' "$*"; }

LAUNCH="$ROOT/scripts/modern-launch"
AUTO="$ROOT/stow/hypr/.config/hypr/modules/autostart.lua"
SESSION="$ROOT/stow/hypr/.config/hypr/modules/session_apps.lua"

if grep -Fq 'hl.dsp.exec_cmd' "$LAUNCH" \
    && ! grep -E '^[[:space:]]*exec hyprctl dispatch exec' "$LAUNCH" >/dev/null; then
    ok "--background uses Lua exec_cmd"
else
    err "modern-launch --background must not call hyprctl dispatch exec"
fi

if grep -Fq 'session_apps' "$AUTO" \
    && grep -Fq 'hl.exec_cmd(cmd, bg_rules)' "$SESSION" \
    && grep -Fq 'special:background silent' "$SESSION" \
    && grep -Fq 'window.class' "$SESSION"; then
    ok "login autostart uses hl.exec_cmd with special:background"
else
    err "autostart.lua must start session_apps with special:background"
fi

if grep -Fq 'window.close' "$SESSION" \
    && grep -Fq 'hideAutostart' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/HyprWindows.qml" \
    && grep -Fq 'closeFocused' "$ROOT/scripts/modern"; then
    ok "close parks autostart apps instead of killing them"
else
    err "close must hide autostart apps to special:background"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-modern-launch: ok\n'
