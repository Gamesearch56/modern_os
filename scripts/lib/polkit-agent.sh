#!/usr/bin/env bash
# Keep Phylax able to show pkexec prompts. Source from scripts/.
# Start if down. After a palette write, bounce so GTK reloads style.css
# (Phylax loads CSS once; it does not watch the file).
# Phylax requires XDG_SESSION_ID (unix-session subject); systemd --user
# only has it after import-environment from a seat session.

POLKIT_AGENT_UNIT="phylax.service"

# Upstream paints "Authenticating..." with the error class. A binary that
# lacks auth-progress still does, so an existing file is not "patched".
phylax_styles_progress() {
    local bin="$1"
    [ -f "$bin" ] && grep -a -F -q 'auth-progress' "$bin"
}

phylax_prebuilt() {
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    printf '%s\n' "$root/install/prebuilt/phylax"
}

install_prebuilt_phylax() {
    local dest="$1"
    local prebuilt
    prebuilt="$(phylax_prebuilt)"
    [ -f "$prebuilt" ] || return 1
    mkdir -p "$(dirname "$dest")"
    install -m 755 "$prebuilt" "$dest"
}

# Upstream Phylax shows an identity DropDown and Confirms as the first
# wheel uid. The patched binary hides that and Confirms as $USER.
ensure_patched_phylax() {
    local bin="${HOME}/.local/bin/phylax"
    local script
    if phylax_styles_progress "$bin"; then
        return 0
    fi
    if install_prebuilt_phylax "$bin"; then
        return 0
    fi
    command -v cargo >/dev/null 2>&1 || return 1
    script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build-phylax.sh"
    [ -f "$script" ] || return 1
    bash "$script"
}

# True unless the running agent was started for another logind session
# than this caller's. Unknown on either side counts as a match.
polkit_agent_in_session() {
    local want pid have
    want="${XDG_SESSION_ID:-}"
    if [ -z "$want" ] && command -v loginctl >/dev/null 2>&1; then
        want="$(loginctl show-user "$(id -un)" -p Display --value 2>/dev/null || true)"
    fi
    pid="$(systemctl --user show -p MainPID --value "$POLKIT_AGENT_UNIT" 2>/dev/null || true)"
    [ -n "$want" ] && [ -n "$pid" ] && [ "$pid" != 0 ] || return 0
    have="$(tr '\0' '\n' <"${POLKIT_AGENT_PROC:-/proc}/$pid/environ" 2>/dev/null \
        | sed -n 's/^XDG_SESSION_ID=//p' | head -n1 || true)"
    [ -z "$have" ] || [ "$have" = "$want" ]
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
        polkit_agent_in_session && return 0
        # Registered for a session that has ended (Restart= after a
        # compositor crash runs before the new login exists): polkit
        # finds no agent for this one and pkexec falls back to /dev/tty.
        systemctl --user restart "$POLKIT_AGENT_UNIT" >/dev/null 2>&1 || true
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
