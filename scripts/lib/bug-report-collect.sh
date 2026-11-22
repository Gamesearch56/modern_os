#!/usr/bin/env bash
# Collectors for scripts/bug-report.sh. Source, never execute. Every
# collector writes one text file into $OUT and tolerates a missing tool:
# a report from a half-broken machine is still a report.
#
# Hard exclusions live in _forbidden, not in the review checklist: a
# toggle can be left on by mistake, a refusal here cannot.

# shellcheck source=bug-report-session.sh
source "$(dirname "${BASH_SOURCE[0]}")/bug-report-session.sh"
# shellcheck source=bug-report-apps.sh
source "$(dirname "${BASH_SOURCE[0]}")/bug-report-apps.sh"
# shellcheck source=bug-report-devices.sh
source "$(dirname "${BASH_SOURCE[0]}")/bug-report-devices.sh"

BUG_REPORT_CAP_BYTES="${BUG_REPORT_CAP_BYTES:-2000000}"
BUG_REPORT_TIMEOUT="${BUG_REPORT_TIMEOUT:-15}"

_forbidden() {
    case "$1" in
        */secrets.json|*/secrets/*|*.env|*/keyrings/*|*/.ssh/*|*/.gnupg/*) return 0 ;;
        */.config/vivaldi*|*/.mozilla/*|*/.config/chromium/*|*/.local/share/keyrings*) return 0 ;;
    esac
    return 1
}

_cap() {
    local f="$1" size
    size="$(wc -c <"$f" 2>/dev/null || printf 0)"
    if [ "$size" -gt "$BUG_REPORT_CAP_BYTES" ]; then
        tail -c "$BUG_REPORT_CAP_BYTES" "$f" >"$f.cap" && mv "$f.cap" "$f"
    fi
}

# _grab <file> <cmd...>: section header plus output (stdout+stderr).
_grab() {
    local name="$1"; shift
    command -v "$1" >/dev/null 2>&1 || return 0
    {
        printf '$ %s\n' "$*"
        timeout "$BUG_REPORT_TIMEOUT" "$@" 2>&1 || printf '[exit %s]\n' "$?"
        printf '\n'
    } >>"$OUT/$name"
}

# _copy <file> <path> [lines]: tail of a log file.
_copy() {
    local name="$1" src="$2" lines="${3:-3000}"
    _forbidden "$src" && return 0
    [ -r "$src" ] || return 0
    { printf '# %s\n' "$src"; tail -n "$lines" "$src"; printf '\n'; } >>"$OUT/$name"
}

_collect_system() {
    local repo="$1" f="$OUT/system.txt"
    {
        printf 'date: %s\n' "$(date -Is)"
        printf 'version: %s\n' "$(git -C "$repo" describe --tags --exact-match 2>/dev/null || true)"
        printf 'release-base: %s\n' "$(git -C "$repo" tag -l 'v*' --sort=-v:refname --no-contains HEAD 2>/dev/null | head -1)"
        printf 'commit: %s\n' "$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
        printf 'kernel: %s\n' "$(uname -r)"
        printf 'uptime: %s\n' "$(uptime -p 2>/dev/null || true)"
        printf 'lang: %s\n' "${LANG:-}"
        printf 'session: %s %s\n' "${XDG_SESSION_TYPE:-}" "${XDG_CURRENT_DESKTOP:-}"
        printf '\n$ git status --porcelain\n'
        git -C "$repo" status --porcelain 2>&1 | head -n 200 || true
    } >"$f"
    _grab failed-units.txt systemctl --failed --no-pager
    _grab failed-units.txt systemctl --user --failed --no-pager
    _grab coredumps.txt coredumpctl list --no-pager --since=-2d
    [ -x "$repo/scripts/doctor.sh" ] && _grab doctor.txt "$repo/scripts/doctor.sh"
    return 0
}

_collect_hyprland() {
    _grab hyprland.txt hyprctl version
    _grab hyprland.txt hyprctl monitors -j
    _grab hyprland.txt hyprctl workspaces -j
    # Window titles carry chats, mail subjects and page names; class,
    # placement and size are enough to place a layout bug.
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        {
            printf '$ hyprctl clients -j (class/workspace/geometry only)\n'
            timeout "$BUG_REPORT_TIMEOUT" hyprctl clients -j 2>/dev/null \
                | jq -c '.[] | {class, workspace: .workspace.name, monitor, floating, fullscreen, at, size, xwayland}' 2>/dev/null || true
            printf '\n'
        } >>"$OUT/hyprland.txt"
    fi
    # Layers place the shell (bar, panels, lock). Devices name the
    # keyboards and mice without dumping keymaps.
    _grab hyprland.txt hyprctl layers -j
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        {
            printf '$ hyprctl devices -j (names only)\n'
            timeout "$BUG_REPORT_TIMEOUT" hyprctl devices -j 2>/dev/null \
                | jq -c '{keyboards: [.keyboards[]? | {name, main}], mice: [.mice[]? | {name, main}], tablets: [.tablets[]?.name]}' 2>/dev/null || true
            printf '\n'
        } >>"$OUT/hyprland.txt"
    fi
    local log notable
    log="$(find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" -maxdepth 2 -name hyprland.log -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2- || true)"
    # The raw log is mostly cursor DEBUG. Keep warnings and errors, and
    # fall back to the last lines only when the recent log has neither.
    if [ -n "$log" ] && ! _forbidden "$log" && [ -r "$log" ]; then
        notable="$(mktemp)"
        tail -c 8000000 "$log" | grep -E '^(ERR|WARN|CRITICAL)' | tail -n 2000 >"$notable" || true
        {
            printf '# %s\n' "$log"
            if [ -s "$notable" ]; then
                printf '# ERR, WARN and CRITICAL only; DEBUG is left out\n'
                cat "$notable"
            else
                printf '# no warnings in the recent log; last lines follow\n'
                tail -n 40 "$log"
            fi
            printf '\n'
        } >>"$OUT/hyprland-log.txt"
        rm -f "$notable"
    fi
}

_collect_logs() {
    local since="$1" state="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
    _grab journal-user.txt journalctl --user -b --since="$since" --no-pager -o short-iso -n 5000
    _grab journal-system.txt journalctl -b -p warning --since="$since" --no-pager -o short-iso -n 5000
    _grab journal-previous-boot.txt journalctl -b -1 -p err --no-pager -o short-iso -n 2000
    # Terminal colors in this log become noise once the file is read as text.
    if ! _forbidden "$state/quickshell.log" && [ -r "$state/quickshell.log" ]; then
        {
            printf '# %s\n' "$state/quickshell.log"
            tail -n 3000 "$state/quickshell.log" | sed 's/\x1b\[[0-9;]*m//g'
            printf '\n'
        } >>"$OUT/quickshell-log.txt"
    fi
    _grab quickshell.txt qs --version
    _grab quickshell.txt quickshell --version
    _grab quickshell-journal.txt journalctl --user -b --since="$since" --no-pager -o short-iso -n 1500 --identifier=quickshell
    _copy update-log.txt "$state/update.log" 2000
    _copy update-log.txt "$state/update.log.1" 1000
    # A full upgrade writes several lines per package plus its hooks.
    _copy pacman-log.txt /var/log/pacman.log 1500
}

# What a failed ModernOS update leaves behind: the exit status and
# markers Settings reads, the root plan, the system step's unit, the
# release history of the checkout and the installer's own log.
_collect_update() {
    local repo="$1" state="${XDG_STATE_HOME:-$HOME/.local/state}/modern" f="$OUT/update.txt" m
    {
        for m in update.rc update.pid reload-pending update-applied release-incomplete root-plan; do
            if [ -f "$state/$m" ]; then
                printf '%s: %s\n' "$m" "$(head -c 2000 "$state/$m" | tr '\n' ' ')"
            else
                printf '%s: (none)\n' "$m"
            fi
        done
        if [ -e /var/lib/modern/update-snapshot ]; then
            printf 'interrupted-update mark: %s\n' "$(cat /var/lib/modern/update-snapshot 2>/dev/null || printf 'unreadable')"
        else
            printf 'interrupted-update mark: (none)\n'
        fi
        printf 'pacman lock: %s\n' "$([ -e /var/lib/pacman/db.lck ] && printf present || printf none)"
        printf '\n$ git tag (newest releases)\n'
        git -C "$repo" tag -l 'v*' --sort=-v:refname 2>/dev/null | head -n 5 || true
        printf '\n$ git reflog (release history)\n'
        git -C "$repo" reflog -n 15 --date=iso 2>/dev/null || true
        printf '\n'
    } >"$f"
    _grab update.txt systemctl status modern-system-update --no-pager -n 0
    _grab update.txt journalctl -b -u modern-system-update --no-pager -o short-iso -n 200
    _grab update.txt snapper -c root list --columns number,date,description
    _copy install-log.txt "$repo/install/install.log" 1500
    # Written once by the ISO installer; the first thing to read when a
    # fresh installation misbehaves.
    _copy install-log.txt /var/log/modern-calamares-late.log 1500
    return 0
}

_collect_config() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
    _forbidden "$cfg" && return 0
    [ -r "$cfg" ] && cp "$cfg" "$OUT/config.json"
    return 0
}

# bug_report_collect <out-dir> <repo> <journal-since>
bug_report_collect() {
    OUT="$1"
    local repo="$2" since="$3" f
    mkdir -p "$OUT"
    rm -f "$OUT"/*
    _collect_system "$repo"
    _collect_device
    _collect_hyprland
    _collect_logs "$since"
    _collect_update "$repo"
    _collect_hardware "$repo"
    _collect_devices "$since"
    _collect_games
    _collect_apps
    _collect_session "$since"
    _collect_boot
    _collect_config
    for f in "$OUT"/*; do
        [ -f "$f" ] && _cap "$f"
    done
    return 0
}
