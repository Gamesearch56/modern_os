#!/usr/bin/env bash
# `modern update`: desktop release + system packages. Source from
# scripts/modern (needs SCRIPT_DIR, cfg, t, ensure_polkit_agent).
#
# Order matters: the password prompt first, then the desktop release,
# then one privileged step for pacman and the release's root needs,
# then the UI reload. Reloading earlier
# restarts the shell — and with it Settings' update process — before
# packages the new release depends on exist.
#
# Without a terminal install.sh cannot sudo, so it writes root work to
# MODERN_ROOT_PLAN. The plan lives in the state dir until the root step
# succeeds: a cancelled auth prompt is retried by the next update even
# though the desktop release no longer shows as pending.

# Stage markers for Settings (Services/UpdateProgress.qml); update-run.sh
# asks for them. A terminal update prints none.
_update_progress() {
    [ -z "${MODERN_UPDATE_PROGRESS:-}" ] || printf '@@progress %s\n' "$*"
}

modern_update() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
    local plan="$state/root-plan" desk_json desk_to="" desk_new=0 pkgs=0 rc=0
    mkdir -p "$state"

    if [ -x "$SCRIPT_DIR/desktop-sync.sh" ]; then
        desk_json="$("$SCRIPT_DIR/desktop-sync.sh" status 2>/dev/null || true)"
        desk_to="$(printf '%s' "$desk_json" | _update_json_field pending to)"
        if [ -n "$desk_to" ]; then
            desk_new=1
        elif [ -s "$plan" ]; then
            desk_to="$(printf '%s' "$desk_json" | _update_json_field "" from)"
        fi
    fi
    if command -v checkupdates >/dev/null 2>&1; then
        pkgs="$(checkupdates 2>/dev/null | grep -c . || true)"
    fi

    # Ask for the password before the desktop release, not after it.
    # A release-only update asks only if it turns out to need root.
    if [ "${pkgs:-0}" -gt 0 ] || [ -s "$plan" ]; then
        if [ -t 0 ]; then
            sudo -v || return 1
        else
            _update_gate_open "$plan" || return 1
        fi
    fi

    if [ "$desk_new" -eq 1 ]; then
        _update_progress desktop
        if [ -t 0 ]; then
            "$SCRIPT_DIR/desktop-sync.sh" apply || return 1
        else
            if ! MODERN_ROOT_PLAN="$plan" "$SCRIPT_DIR/desktop-sync.sh" apply; then
                _update_gate_send skip || true
                return 1
            fi
        fi
    fi

    if [ "${pkgs:-0}" -gt 0 ] || [ -s "$plan" ]; then
        if [ -t 0 ]; then
            _update_tty "$plan" || return 1
        else
            [ -n "${_UPDATE_GATE_FD:-}" ] || _update_gate_open "$plan" || return 1
            [ "$(cfg backup.preUpdateSnapshot true)" != "true" ] || t cli.snapshotting
            _update_progress system "${pkgs:-0}"
            _update_gate_send go || rc=$?
            [ "$rc" -eq 0 ] || return "$rc"
        fi
        rm -f "$plan"
    fi

    [ -n "$desk_to" ] || return 0
    # Settings' Update service reads this after the reload restarts it.
    printf '%s\n' "$desk_to" >"$state/update-applied"
    local reload="${MODERN_RELOAD_UI:-$SCRIPT_DIR/reload-ui.sh}"
    [ -x "$reload" ] || return 0
    # Settings shows the finished update first, then runs
    # `update-run.sh reload`.
    if [ -n "${MODERN_UPDATE_DEFER_RELOAD:-}" ]; then
        : >"$MODERN_UPDATE_DEFER_RELOAD"
        return 0
    fi
    if [ -t 0 ]; then
        "$reload" || true
    else
        # Detached: the Quickshell reload tears down the Process that
        # runs us, and must not cut reload-ui.sh off halfway.
        setsid -f "$reload" </dev/null >/dev/null 2>&1 || true
    fi
}

# Starts `pkexec update-apply.sh --wait` (the password prompt) with its
# stdin on a FIFO; _update_gate_send releases it. The root plan path is
# fixed now; its contents are read only after "go".
_update_gate_open() {
    local plan="$1" fifo snap_flag=--no-snapshot
    local extra=(--wait --root-plan "$plan")
    [ "$(cfg backup.preUpdateSnapshot true)" != "true" ] || snap_flag=--snapshot
    [ -z "${MODERN_UPDATE_PROGRESS:-}" ] || extra+=(--progress)
    ensure_polkit_agent || true
    fifo="$(mktemp -u "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/modern-update-gate.XXXXXX")"
    mkfifo -m 0600 "$fifo" || return 1
    "${MODERN_PKEXEC:-pkexec}" "$SCRIPT_DIR/update-apply.sh" "$snap_flag" "${extra[@]}" <"$fifo" &
    _UPDATE_GATE_PID=$!
    exec {_UPDATE_GATE_FD}>"$fifo"
    rm -f "$fifo"
}

# Sends "go" or "skip" and returns the root step's exit status. A prompt
# cancelled earlier has closed the FIFO; the write fails in a subshell
# so SIGPIPE cannot take this shell down with it.
_update_gate_send() {
    local rc=0
    [ -n "${_UPDATE_GATE_FD:-}" ] || return 0
    (printf '%s\n' "$1" >&"$_UPDATE_GATE_FD") 2>/dev/null || true
    exec {_UPDATE_GATE_FD}>&-
    _UPDATE_GATE_FD=""
    wait "$_UPDATE_GATE_PID" || rc=$?
    return "$rc"
}

modern_update_notice() {
    local marker="${XDG_STATE_HOME:-$HOME/.local/state}/modern/update-applied"
    [ -f "$marker" ] || return 0
    head -n1 "$marker"
    rm -f "$marker"
}

# Prints field $2 of the JSON on stdin; empty unless key $1 is truthy.
_update_json_field() {
    python3 -c 'import json,sys
d=json.load(sys.stdin)
print(d.get(sys.argv[2]) or "" if not sys.argv[1] or d.get(sys.argv[1]) else "")' "$1" "$2" 2>/dev/null || true
}

_update_tty() {
    local plan="$1"
    if [ "$(cfg backup.preUpdateSnapshot true)" = "true" ]; then
        if command -v snapper >/dev/null 2>&1 && snapper list-configs >/dev/null 2>&1 \
            && snapper list-configs 2>/dev/null | grep -q root; then
            t cli.snapshotting
            sudo /usr/bin/snapper -c root create --description "ModernOS Update" || {
                t cli.snapshotFailed >&2
                return 1
            }
            sudo "$SCRIPT_DIR/snapper-gc.sh" prune-from-config "$CFG" || true
        else
            t cli.snapperUnconfigured >&2 || true
        fi
    fi
    if [ -s "$plan" ]; then
        sudo "$SCRIPT_DIR/update-apply.sh" --no-snapshot --root-plan "$plan" || return 1
    fi
    yay -Syu
}
