#!/usr/bin/env bash
# Block logind's default lid and power-key actions for this session.
# HandleLidSwitch=suspend / HandlePowerKey=poweroff would ignore
# Settings → Energy. Hyprland binds then call `modern power`.
set -euo pipefail

command -v systemd-inhibit >/dev/null 2>&1 || exit 0

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
mkdir -p "$LOCK_DIR"
exec 8>"$LOCK_DIR/modern-logind-handles.lock"
flock -n 8 || exit 0

exec systemd-inhibit \
    --what=handle-lid-switch:handle-power-key:handle-suspend-key \
    --who=modern \
    --why="Energy settings" \
    --mode=block \
    sleep infinity
