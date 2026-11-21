#!/usr/bin/env bash
# Collectors for scripts/bug-report.sh. Source, never execute. Every
# collector writes one text file into $OUT and tolerates a missing tool:
# a report from a half-broken machine is still a report.
#
# Hard exclusions live in _forbidden, not in the review checklist: a
# toggle can be left on by mistake, a refusal here cannot.

# shellcheck source=bug-report-session.sh
source "$(dirname "${BASH_SOURCE[0]}")/bug-report-session.sh"

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
        timeout "$BUG_REPORT_TIMEOUT" "$@" 2>&1 || true
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
    return 0
}

_collect_hardware() {
    _grab hardware.txt lspci -k
    _grab hardware.txt lsusb
    _grab hardware.txt free -h
    _grab hardware.txt df -h -x tmpfs -x devtmpfs
    [ -x "$1/scripts/battery-read.sh" ] && _grab hardware.txt "$1/scripts/battery-read.sh"
    return 0
}

_collect_devices() {
    local since="$1" addr
    _grab audio.txt wpctl status
    _grab audio.txt pactl info
    _grab audio.txt pactl list sinks short
    _grab audio.txt pactl list cards short
    # Quantum and rate decide latency; the Bluetooth card's profile and
    # codec decide whether a headset is on A2DP (AAC/LDAC/SBC) or the
    # call profile.
    _grab audio.txt pw-metadata -n settings
    if command -v pactl >/dev/null 2>&1; then
        {
            printf '$ pactl list cards (Bluetooth profile and codec)\n'
            timeout "$BUG_REPORT_TIMEOUT" pactl list cards 2>/dev/null \
                | grep -E '^Card|Name: bluez|Active Profile|api\.bluez5\.(codec|profile|transport)' || true
            printf '\n'
        } >>"$OUT/audio.txt"
    fi
    _grab bluetooth.txt bluetoothctl show
    _grab bluetooth.txt bluetoothctl devices Connected
    # Paired, trusted, bonded and the per-transport state show whether a
    # headset has a bare link or real audio.
    if command -v bluetoothctl >/dev/null 2>&1; then
        while read -r _ addr _; do
            [ -n "$addr" ] && _grab bluetooth.txt bluetoothctl info "$addr"
        done < <(timeout "$BUG_REPORT_TIMEOUT" bluetoothctl devices Paired 2>/dev/null || true)
    fi
    _grab bluetooth.txt journalctl -b -u bluetooth --since="$since" --no-pager -o short-iso -n 500
    _grab bluetooth.txt journalctl --user -b -u wireplumber --since="$since" --no-pager -o short-iso -n 500
    _grab network.txt nmcli general
    _grab network.txt nmcli -f DEVICE,TYPE,STATE device
    _grab network.txt nmcli networking connectivity
    _grab network.txt nmcli radio
    _grab network.txt rfkill list
    # The world domain "00" limits 5 GHz channels and transmit power.
    _grab network.txt iw reg get
    # The joined network's band, signal and rate, without its name.
    _grab network.txt nmcli -f IN-USE,SIGNAL,FREQ,CHAN,RATE,SECURITY device wifi list
    _grab network.txt journalctl -b -u NetworkManager --since="$since" --no-pager -o short-iso -n 500
    _grab network.txt journalctl -b -u wpa_supplicant --since="$since" --no-pager -o short-iso -n 300
}

_collect_games() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
    _grab games.txt umu-run --version
    _copy games.txt "$state/battlenet.log" 1500
    local tools="${HOME}/.local/share/Steam/compatibilitytools.d"
    [ -d "$tools" ] && { printf '$ ls compatibilitytools.d\n'; ls "$tools"; printf '\n'; } >>"$OUT/games.txt"
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
    _collect_hyprland
    _collect_logs "$since"
    _collect_update "$repo"
    _collect_hardware "$repo"
    _collect_devices "$since"
    _collect_games
    _collect_session "$since"
    _collect_boot
    _collect_config
    for f in "$OUT"/*; do
        [ -f "$f" ] && _cap "$f"
    done
    return 0
}
