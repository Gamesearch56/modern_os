#!/usr/bin/env bash
# Keep Phylax able to show pkexec prompts. Source from scripts/.
# Start if down. After a palette write, bounce so GTK reloads style.css
# (Phylax loads CSS once; it does not watch the file).
# Phylax requires XDG_SESSION_ID (unix-session subject); systemd --user
# only has it after import-environment from a seat session.

POLKIT_AGENT_UNIT="phylax.service"

# Upstream Phylax shows an identity DropDown and Confirms as the first
# wheel uid. The patched binary hides that and Confirms as $USER.
ensure_patched_phylax() {
    local bin="${HOME}/.local/bin/phylax"
    local script
    if [ -x "$bin" ]; then
        return 0
    fi
    command -v cargo >/dev/null 2>&1 || return 1
    script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build-phylax.sh"
    [ -f "$script" ] || return 1
    bash "$script"
}

ensure_polkit_agent() {
    command -v systemctl >/dev/null 2>&1 || return 1
    ensure_patched_phylax || true
    systemctl --user stop hyprpolkitagent.service >/dev/null 2>&1 || true
    if [ -n "${XDG_SESSION_ID:-}" ]; then
        systemctl --user import-environment XDG_SESSION_ID XDG_SESSION_TYPE WAYLAND_DISPLAY >/dev/null 2>&1 || true
    fi
    systemctl --user reset-failed "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    if systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
        return 0
    fi
    systemctl --user start "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    if ! systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user start "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    fi
    local _i
    for _i in 1 2 3 4 5 6 7 8 9 10; do
        if systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
            sleep 0.2
            if systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
                return 0
            fi
        fi
        sleep 0.1
    done
    return 1
}

# Reload style.css into a running agent. Debounced so chrome-only bursts
# from ConfigWrite do not burn StartLimitBurst and leave pkexec silent.
reload_polkit_theme() {
    command -v systemctl >/dev/null 2>&1 || return 1
    local stamp="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/modern-phylax-theme-reload"
    local now last=0
    now="$(date +%s)"
    if [ -f "$stamp" ]; then
        last="$(cat "$stamp" 2>/dev/null || printf '0')"
        case "$last" in
            '' | *[!0-9]*) last=0 ;;
        esac
        if [ $((now - last)) -lt 3 ]; then
            return 0
        fi
    fi
    printf '%s\n' "$now" >"$stamp" || true
    ensure_polkit_agent || return 1
    systemctl --user reset-failed "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    if ! systemctl --user try-restart "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
        systemctl --user restart "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
    fi
    local _i
    for _i in 1 2 3 4 5 6 7 8 9 10; do
        if systemctl --user is-active "$POLKIT_AGENT_UNIT" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}
