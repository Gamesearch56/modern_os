#!/usr/bin/env bash
# Read/set display brightness for Services/Brightness.qml.
# Laptop panels: brightnessctl class backlight. External monitors: ddcutil
# VCP 10. LED class devices (numlock, NIC) are never used.
set -euo pipefail

emit() {
    printf '{"available":%s,"percent":%s,"backend":"%s","display":%s}\n' "$1" "$2" "$3" "$4"
}

first_ddc_display() {
    command -v ddcutil >/dev/null 2>&1 || return 1
    local n
    n="$(ddcutil detect --brief 2>/dev/null | grep -i -m1 -oE 'display[[:space:]]+[0-9]+' | grep -oE '[0-9]+' || true)"
    if [ -n "${n}" ]; then
        printf '%s\n' "$n"
        return 0
    fi
    return 1
}

backlight_pct() {
    local line class pct
    line="$(brightnessctl -m -c backlight 2>/dev/null | head -n1 || true)"
    [ -n "${line}" ] || return 1
    class="$(printf '%s' "$line" | cut -d, -f2)"
    pct="$(printf '%s' "$line" | cut -d, -f4)"
    pct="${pct%%%}"
    [ "${class}" = "backlight" ] || return 1
    [[ "${pct}" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$pct"
}

ddc_read() {
    local disp out n
    disp="$(first_ddc_display)" || return 1
    out="$(ddcutil getvcp 10 --brief --display "${disp}" 2>/dev/null || true)"
    n="$(awk '{ for (i = 1; i <= NF; i++) if ($i == "VCP") { print $(i+3); exit } }' <<<"${out}")"
    [[ "${n}" =~ ^[0-9]+$ ]] || return 1
    printf '%s %s\n' "${disp}" "${n}"
}

clamp() {
    local v="$1"
    if [ "$v" -lt 1 ]; then
        v=1
    elif [ "$v" -gt 100 ]; then
        v=100
    fi
    printf '%s\n' "$v"
}

set_pct() {
    local v disp
    v="$(clamp "$1")"
    if backlight_pct >/dev/null; then
        brightnessctl -c backlight set "${v}%"
        return 0
    fi
    disp="$(first_ddc_display)" || return 1
    ddcutil setvcp 10 "${v}" --display "${disp}"
}

cmd="${1:-get}"
case "${cmd}" in
    get)
        if pct="$(backlight_pct)"; then
            emit true "${pct}" brightnessctl 0
        elif pair="$(ddc_read)"; then
            emit true "${pair##* }" ddcutil "${pair%% *}"
        else
            emit false 100 none 0
        fi
        ;;
    set)
        [[ "${2:-}" =~ ^[0-9]+$ ]] || exit 2
        set_pct "$2"
        ;;
    up)
        if pct="$(backlight_pct)"; then
            set_pct $((pct + 5))
        elif pair="$(ddc_read)"; then
            set_pct $((${pair##* } + 5))
        else
            exit 1
        fi
        ;;
    down)
        if pct="$(backlight_pct)"; then
            set_pct $((pct - 5))
        elif pair="$(ddc_read)"; then
            set_pct $((${pair##* } - 5))
        else
            exit 1
        fi
        ;;
    *)
        echo "usage: brightness.sh get|set PERCENT|up|down" >&2
        exit 2
        ;;
esac
