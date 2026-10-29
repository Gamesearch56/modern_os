#!/usr/bin/env bash
# `modern update`: desktop release + system packages. Source from
# scripts/modern (needs SCRIPT_DIR, cfg, t, ensure_polkit_agent).
#
# Order matters: desktop release, then one privileged step for pacman
# and the release's root needs, then the UI reload. Reloading earlier
# restarts the shell — and with it Settings' update process — before
# packages the new release depends on exist.
#
# Without a terminal install.sh cannot sudo, so it writes root work to
# MODERN_ROOT_PLAN. The plan lives in the state dir until the root step
# succeeds: a cancelled auth prompt is retried by the next update even
# though the desktop release no longer shows as pending.

modern_update() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
    local plan="$state/root-plan" desk_json desk_to="" has_pkgs=0 snap_flag rc=0
    mkdir -p "$state"

    if [ -x "$SCRIPT_DIR/desktop-sync.sh" ]; then
        desk_json="$("$SCRIPT_DIR/desktop-sync.sh" status 2>/dev/null || true)"
        desk_to="$(printf '%s' "$desk_json" | _update_json_field pending to)"
        if [ -n "$desk_to" ]; then
            if [ -t 0 ]; then
                "$SCRIPT_DIR/desktop-sync.sh" apply || return 1
            else
                MODERN_ROOT_PLAN="$plan" "$SCRIPT_DIR/desktop-sync.sh" apply || return 1
            fi
        elif [ -s "$plan" ]; then
            desk_to="$(printf '%s' "$desk_json" | _update_json_field "" from)"
        fi
    fi

    if command -v checkupdates >/dev/null 2>&1 && checkupdates 2>/dev/null | grep -q .; then
        has_pkgs=1
    fi

    if [ "$has_pkgs" -eq 1 ] || [ -s "$plan" ]; then
        if [ -t 0 ]; then
            _update_tty "$plan" || return 1
        else
            snap_flag=--no-snapshot
            if [ "$(cfg backup.preUpdateSnapshot true)" = "true" ]; then
                snap_flag=--snapshot
                t cli.snapshotting
            fi
            ensure_polkit_agent || true
            local plan_args=()
            [ -s "$plan" ] && plan_args=(--root-plan "$plan")
            "${MODERN_PKEXEC:-pkexec}" "$SCRIPT_DIR/update-apply.sh" "$snap_flag" "${plan_args[@]}" || rc=$?
            [ "$rc" -eq 0 ] || return "$rc"
        fi
        rm -f "$plan"
    fi

    [ -n "$desk_to" ] || return 0
    # Settings' Update service reads this after the reload restarts it.
    printf '%s\n' "$desk_to" >"$state/update-applied"
    local reload="${MODERN_RELOAD_UI:-$SCRIPT_DIR/reload-ui.sh}"
    [ -x "$reload" ] || return 0
    if [ -t 0 ]; then
        "$reload" || true
    else
        # Detached: the Quickshell reload tears down the Process that
        # runs us, and must not cut reload-ui.sh off halfway.
        setsid -f "$reload" </dev/null >/dev/null 2>&1 || true
    fi
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
