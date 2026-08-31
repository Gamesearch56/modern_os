#!/usr/bin/env bash
# Keep hyprpolkitagent able to show pkexec prompts. Source from scripts/.
# try-restart on every theme-apply hits systemd StartLimit (5/10s) and
# leaves pkexec hanging with no dialog — start if down, do not bounce.

POLKIT_AGENT_UNIT="hyprpolkitagent.service"

ensure_polkit_agent() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl --user reset-failed "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    if systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
        return 0
    fi
    systemctl --user start "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    local _i
    for _i in 1 2 3 4 5 6 7 8 9 10; do
        if systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}
