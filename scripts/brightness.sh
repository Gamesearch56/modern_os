#!/usr/bin/env bash
# Read/set display brightness for Services/Brightness.qml.
# Laptop panels: brightnessctl class backlight. External monitors: ddcutil
# VCP 10. LED class devices (numlock, NIC) are never used.
# Every ddcutil call is wrapped in timeout — hung I2C must not block the shell.
set -euo pipefail

DDC_TIMEOUT_SEC="${MODERN_DDC_TIMEOUT_SEC:-5}"
DDC_DETECT_TIMEOUT_SEC="${MODERN_DDC_DETECT_TIMEOUT_SEC:-10}"

ddc() {
    command -v ddcutil >/dev/null 2>&1 || return 1
    timeout "${DDC_TIMEOUT_SEC}" ddcutil "$@" 2>/dev/null
}

emit() {
    printf '{"available":%s,"percent":%s,"backend":"%s","display":%s}\n' "$1" "$2" "$3" "$4"
}

first_ddc_display() {
    local n
    n="$(ddc detect --brief | grep -i -m1 -oE 'display[[:space:]]+[0-9]+' | grep -oE '[0-9]+' || true)"
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
    out="$(ddc getvcp 10 --brief --display "${disp}" || true)"
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
        ddc setvcp 10 "${v}" --display "$2"
        return $?
    fi
    if backlight_pct >/dev/null; then
        brightnessctl -c backlight set "${v}%"
        return 0
    fi
    disp="$(first_ddc_display)" || return 1
    ddc setvcp 10 "${v}" --display "${disp}"
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
        MODERN_DDC_TIMEOUT_SEC="${DDC_TIMEOUT_SEC}" \
        MODERN_DDC_DETECT_TIMEOUT_SEC="${DDC_DETECT_TIMEOUT_SEC}" \
        python3 - <<'PY'
import json, os, re, shutil, subprocess

timeout = int(os.environ.get("MODERN_DDC_TIMEOUT_SEC", "5"))
detect_t = int(os.environ.get("MODERN_DDC_DETECT_TIMEOUT_SEC", "10"))

def run(cmd, t=timeout):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True, timeout=t)
    except Exception:
        return ""

displays = []
line = run(["brightnessctl", "-m", "-c", "backlight"], t=3).splitlines()
if line:
    parts = line[0].split(",")
    if len(parts) >= 4 and parts[1] == "backlight":
        pct = parts[3].replace("%", "")
        if pct.isdigit():
            displays.append({
                "id": 0, "model": "", "serial": "", "connector": "",
                "percent": int(pct), "backend": "brightnessctl", "ok": True
            })

pending = []
if shutil.which("ddcutil"):
    text = run(["timeout", str(detect_t), "ddcutil", "detect"], t=detect_t + 1)
    current = None

    def push(cur):
        if cur:
            pending.append(cur)

    for raw in text.splitlines():
        line = raw.strip()
        m = re.match(r"Display\s+(\d+)\b", line)
        if m:
            push(current)
            current = {
                "id": int(m.group(1)), "model": "", "serial": "",
                "connector": "", "percent": 0, "backend": "ddcutil", "ok": False
            }
            continue
        if not current:
            continue
        cm = re.search(r"(?i)\b((?:DP|HDMI|eDP|DVI|VGA)-\d+)\b", line)
        if cm and "connector" in line.lower():
            current["connector"] = cm.group(1)
        mm = re.search(r"^Model:\s+(.+)$", line)
        if mm:
            current["model"] = mm.group(1).strip()
        sm = re.search(r"^Serial number:\s*(.*)$", line)
        if sm and sm.group(1).strip():
            current["serial"] = sm.group(1).strip()
        bm = re.search(r"^Binary serial number:\s*(\d+)", line)
        if bm and not current["serial"]:
            current["serial"] = "0x%08X" % int(bm.group(1))
    push(current)

    procs = []
    for cur in pending:
        try:
            p = subprocess.Popen(
                ["timeout", str(timeout), "ddcutil", "getvcp", "10",
                 "--brief", "--display", str(cur["id"])],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
            )
            procs.append((cur, p))
        except Exception:
            displays.append(cur)

    def read_vcp(disp_id):
        try:
            return run([
                "timeout", str(timeout), "ddcutil", "getvcp", "10",
                "--brief", "--display", str(disp_id)
            ])
        except Exception:
            return ""

    for cur, p in procs:
        try:
            out, _ = p.communicate(timeout=timeout + 1)
        except Exception:
            try:
                p.kill()
            except Exception:
                pass
            out = ""
        m = re.search(r"VCP\s+\S+\s+\S+\s+(\d+)", out or "")
        if not m:
            out = read_vcp(cur["id"])
            m = re.search(r"VCP\s+\S+\s+\S+\s+(\d+)", out or "")
        if m:
            cur["percent"] = int(m.group(1))
            cur["ok"] = True
        displays.append(cur)

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
