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
    if [ -n "${2:-}" ]; then
        ddcutil setvcp 10 "${v}" --display "$2"
        return 0
    fi
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
        if [ -n "${3:-}" ]; then
            [[ "${3}" =~ ^[0-9]+$ ]] || exit 2
            set_pct "$2" "$3"
        else
            set_pct "$2"
        fi
        ;;
    list)
        python3 - <<'PY'
import json, re, shutil, subprocess

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True, timeout=8)
    except Exception:
        return ""

displays = []
line = run(["brightnessctl", "-m", "-c", "backlight"]).splitlines()
if line:
    parts = line[0].split(",")
    if len(parts) >= 4 and parts[1] == "backlight":
        pct = parts[3].replace("%", "")
        if pct.isdigit():
            displays.append({
                "id": 0, "model": "", "serial": "",
                "percent": int(pct), "backend": "brightnessctl"
            })

if shutil.which("ddcutil"):
    text = run(["ddcutil", "detect"])
    current = None

    def flush(cur):
        if not cur:
            return
        out = run(["ddcutil", "getvcp", "10", "--brief", "--display", str(cur["id"])])
        m = re.search(r"VCP\s+\S+\s+\S+\s+(\d+)", out)
        if m:
            cur["percent"] = int(m.group(1))
        displays.append(cur)

    for raw in text.splitlines():
        line = raw.strip()
        m = re.match(r"Display\s+(\d+)\b", line)
        if m:
            flush(current)
            current = {
                "id": int(m.group(1)), "model": "", "serial": "",
                "percent": 0, "backend": "ddcutil"
            }
            continue
        if not current:
            continue
        mm = re.search(r"^Model:\s+(.+)$", line)
        if mm:
            current["model"] = mm.group(1).strip()
        sm = re.search(r"^Serial number:\s+(.+)$", line)
        if sm:
            current["serial"] = sm.group(1).strip()
    flush(current)

print(json.dumps({"displays": displays}))
PY
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
    dim)
        state="${XDG_STATE_HOME:-$HOME/.local/state}/modern/brightness-undim"
        mkdir -p "$(dirname "$state")"
        if pct="$(backlight_pct)"; then
            printf '%s\n' "$pct" >"$state"
            set_pct $((pct < 20 ? 1 : pct / 10))
        elif pair="$(ddc_read)"; then
            cur="${pair##* }"
            printf '%s\n' "$cur" >"$state"
            set_pct $((cur < 20 ? 1 : cur / 10))
        else
            exit 1
        fi
        ;;
    undim)
        state="${XDG_STATE_HOME:-$HOME/.local/state}/modern/brightness-undim"
        if [ -f "$state" ]; then
            set_pct "$(cat "$state")"
            rm -f "$state"
        fi
        ;;
    *)
        echo "usage: brightness.sh get|set PERCENT [DISPLAY]|up|down|dim|undim|list" >&2
        exit 2
        ;;
esac
