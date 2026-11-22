#!/usr/bin/env bash
# Boot, login, lock and shutdown collectors for scripts/bug-report.sh.
# Sourced by bug-report-collect.sh; uses its _grab, _copy and $OUT.
#
# The chain these cover: boot entry and kernel command line, the splash,
# greetd and the login screen, the desktop session wrapper and its shell,
# the lock screen and idle daemon, and how the previous boot shut down.

_session_shared() {
    printf '%s\n' "${BUG_REPORT_SESSION_DIR:-/var/lib/modern/session}"
}

_running() {
    pgrep -u "$(id -u)" "$@" >/dev/null 2>&1 && printf yes || printf no
}

_collect_boot() {
    local repo="${1:-}"
    _grab boot.txt cat /proc/cmdline
    _grab boot.txt systemd-analyze
    _grab boot.txt systemd-analyze critical-chain graphical.target --no-pager
    _grab boot.txt bootctl list --no-pager
    _grab boot.txt journalctl -b --no-pager -o short-iso -n 300 \
        -u plymouth-start -u plymouth-quit -u plymouth-quit-wait -u plymouth-read-write \
        -u modern-splash -u modern-boot-confirm -u greetd
    # The firmware-logo gaps are info-level kernel lines (an ignored
    # i915 parameter, the efifb handover). Warning-only logs hide them.
    _grab boot.txt journalctl -b -k --no-pager -o short-iso -n 400 \
        -g 'i915:|fb0:|unknown parameter|drm:'
    # The end of the previous boot is its shutdown: a unit that would not
    # stop, or a crash instead of a clean power-off, shows here.
    _grab boot.txt journalctl -b -1 --no-pager -o short-iso -n 300
    if [ -n "$repo" ] && [ -x "$repo/scripts/boot-gaps.sh" ]; then
        gaps="$(mktemp)"
        "$repo/scripts/boot-gaps.sh" "$OUT/boot.txt" "$OUT/hyprland-log.txt" \
            "${XDG_STATE_HOME:-$HOME/.local/state}/modern/hyprland.log" >"$gaps" || true
        {
            printf '$ boot-gaps\n'
            cat "$gaps"
            printf '\n'
        } >>"$OUT/boot.txt"
        rm -f "$gaps"
    fi
    return 0
}

_collect_session() {
    local since="$1" state="${XDG_STATE_HOME:-$HOME/.local/state}/modern" shared
    local run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" f="$OUT/session.txt"
    shared="$(_session_shared)"
    {
        printf 'session-locked marker: %s\n' "$(cat "$run/modern-session-locked" 2>/dev/null || printf '(none)')"
        printf 'shell running: %s\n' "$(_running -xf 'qs -c modern')"
        printf 'shell supervisor running: %s\n' "$(_running -f 'shell-run.sh')"
        printf 'hypridle running: %s\n' "$(_running -x hypridle)"
        printf 'logind inhibitor running: %s\n\n' "$(_running -f 'Energy settings')"
    } >"$f"
    _grab session.txt loginctl show-session "${XDG_SESSION_ID:-auto}" \
        -p Type -p Class -p Service -p State -p Active -p LockedHint -p IdleHint
    _grab session.txt systemd-inhibit --list --no-pager
    # splash-hold.sh, modern power and shell-run.sh log under these tags.
    _grab session.txt journalctl -b --since="$since" --no-pager -o short-iso -n 300 \
        -t modern-session -t modern-power -t modern-shell
    _grab session.txt journalctl -b -u greetd --since="$since" --no-pager -o short-iso -n 500
    _copy session.txt "$shared/auth-trace.json" 40
    _copy session.txt "$shared/greeter.log" 400
    _session_hyprland "$state/hyprland.log"
    _copy session.txt "$state/hypridle.log" 300
    return 0
}

# Hyprland's stdout repeats its debug log, window titles included. Keep
# the per-login headers, warnings, errors and the watchdog's own lines.
_session_hyprland() {
    local log="$1"
    _forbidden "$log" && return 0
    [ -r "$log" ] || return 0
    {
        printf '# %s (session headers, warnings, errors and crashes only)\n' "$log"
        tail -c 4000000 "$log" | sed 's/\x1b\[[0-9;]*m//g' \
            | grep -E '^== |^(ERR|WARN|CRITICAL)|drm: |seat-cover: |start-hyprland|[Ww]atchdog|[Cc]rash|[Ss]afe mode' \
            | tail -n 400 || true
        printf '\n'
    } >>"$OUT/session.txt"
}
