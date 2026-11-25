#!/usr/bin/env bash
# HDR console values for WoW Forever. The gamescope launcher turns them
# on and holds the lock for the whole game. Battle.net turns them off
# only while that lock is free and the game is not running, so a Play
# click starts the desktop copy with HDR output disabled.
# Source, never execute.

WOW_HDR_LOCK="${WOW_HDR_LOCK:-${XDG_STATE_HOME:-$HOME/.local/state}/modern/wow-hdr.lock}"

wow_forever_config() {
    if [ -n "${WOW_CONFIG:-}" ]; then
        printf '%s\n' "$WOW_CONFIG"
        return 0
    fi
    local rel="drive_c/Program Files (x86)/World of Warcraft/_forever_/WTF/Config.wtf"
    local steam="${STEAM_ROOT:-$HOME/.local/share/Steam}"
    local prefix candidate
    local -a prefixes=()
    prefixes+=("${XDG_DATA_HOME:-$HOME/.local/share}/modern/battlenet/pfx")
    prefixes+=("$HOME/Games/battlenet")
    if [ -d "$steam/steamapps/compatdata" ]; then
        for prefix in "$steam"/steamapps/compatdata/*/pfx; do
            [ -d "$prefix" ] && prefixes+=("$prefix")
        done
    fi
    for prefix in "${prefixes[@]}"; do
        candidate="$prefix/$rel"
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# $1 is on or off. $2 is the peak brightness written only when turning on.
wow_hdr_apply() {
    local mode="$1" peak="${2:-}"
    local file tmp dir nl line key
    file="$(wow_forever_config)" || return 0
    [ -f "$file" ] || return 0
    local -A want=()
    if [ "$mode" = "on" ]; then
        want[HDROutput]=1
        want[useHDRPeakBrightness]=1
        want[useHDRBrightness]=1
        if [ -n "$peak" ]; then
            want[HDRPeakBrightness]="$peak"
        fi
    else
        want[HDROutput]=0
        want[useHDRPeakBrightness]=0
        want[useHDRBrightness]=0
    fi
    nl=$'\n'
    if LC_ALL=C grep -q $'\r' "$file"; then
        nl=$'\r\n'
    fi
    dir="$(dirname "$file")"
    tmp="$(mktemp "$dir/Config.wtf.XXXX")"
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [[ "$line" =~ ^SET[[:space:]]+([A-Za-z0-9_]+)[[:space:]] ]]; then
            key="${BASH_REMATCH[1]}"
            if [ -n "${want[$key]+x}" ]; then
                printf 'SET %s "%s"%s' "$key" "${want[$key]}" "$nl"
                unset "want[$key]"
                continue
            fi
        fi
        printf '%s%s' "$line" "$nl"
    done <"$file" >"$tmp"
    for key in "${!want[@]}"; do
        printf 'SET %s "%s"%s' "$key" "${want[$key]}" "$nl" >>"$tmp"
    done
    mv -f "$tmp" "$file"
}

# Hold the lock across exec so Battle.net cannot switch HDR off under
# a game that is about to read Config.wtf.
wow_hdr_hold_on() {
    local peak="${1:-}"
    mkdir -p "$(dirname "$WOW_HDR_LOCK")"
    exec 9>"$WOW_HDR_LOCK"
    flock 9
    wow_hdr_apply on "$peak"
}

wow_game_running() {
    if [ "${WOW_HDR_ASSUME_IDLE:-}" = 1 ]; then
        return 1
    fi
    pgrep -x Wow.exe >/dev/null 2>&1
}

wow_hdr_off_if_idle() {
    mkdir -p "$(dirname "$WOW_HDR_LOCK")"
    exec 8>"$WOW_HDR_LOCK"
    if ! flock -n 8; then
        return 0
    fi
    if ! wow_game_running; then
        wow_hdr_apply off || true
    fi
    flock -u 8
}

