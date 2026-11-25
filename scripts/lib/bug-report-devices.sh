#!/usr/bin/env bash
# Hardware, device and games collectors for scripts/bug-report.sh,
# sourced by bug-report-collect.sh (which defines _grab and _copy).

# Driver stacks that decide most display and game bugs; pacman -Q also
# names the ones that are missing.
BUG_REPORT_PACKAGES=(linux linux-zen linux-lts hyprland quickshell aquamarine mesa
    vulkan-radeon vulkan-intel nvidia nvidia-open nvidia-open-dkms nvidia-utils
    pipewire wireplumber bluez networkmanager)

_dmi() {
    local v
    v="$(tr -d '\n' <"/sys/class/dmi/id/$1" 2>/dev/null || true)"
    case "$v" in
        ""|"To Be Filled By O.E.M."|"Default string"|"System Product Name"|"Not Applicable") ;;
        *) printf '%s' "$v" ;;
    esac
}

_chassis() {
    case "$(_dmi chassis_type)" in
        8|9|10|14|31|32) printf 'laptop' ;;
        30) printf 'tablet' ;;
        3|4|5|6|7|15|16|35|36) printf 'desktop' ;;
        13) printf 'all-in-one' ;;
        *) printf 'unknown' ;;
    esac
}

_boot_mode() {
    local sb
    [ -d /sys/firmware/efi ] || { printf 'BIOS (legacy)'; return; }
    sb="$(od -An -tu1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | tr -d ' ')"
    case "$sb" in
        1) printf 'UEFI, Secure Boot on' ;;
        0) printf 'UEFI, Secure Boot off' ;;
        *) printf 'UEFI' ;;
    esac
}

# Graphics cards with the kernel driver bound to each.
_gpus() {
    local dev class name driver
    for dev in /sys/bus/pci/devices/*; do
        class="$(cat "$dev/class" 2>/dev/null || true)"
        case "$class" in 0x03*) ;; *) continue ;; esac
        name="$(lspci -s "${dev##*/}" 2>/dev/null | cut -d' ' -f2- | sed 's/^[^:]*: //')"
        driver="$(basename "$(readlink "$dev/driver" 2>/dev/null)" 2>/dev/null || true)"
        printf 'gpu: %s (driver %s)\n' "${name:-${dev##*/}}" "${driver:-none}"
    done
}

# The facts a maintainer reads first, one "key: value" per line. Model
# names only: DMI serials and UUIDs, and monitor serials, stay out.
_collect_device() {
    local f="$OUT/device.txt" os=""
    [ -r /etc/os-release ] && os="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-}")"
    {
        printf 'os: %s (%s)\n' "${os:-unknown}" "$(uname -m)"
        printf 'machine: %s\n' "$(printf '%s %s %s' "$(_dmi sys_vendor)" "$(_dmi product_name)" "$(_dmi product_version)" | xargs)"
        printf 'form: %s\n' "$(_chassis)"
        printf 'firmware: %s\n' "$(printf '%s %s %s' "$(_dmi bios_vendor)" "$(_dmi bios_version)" "$(_dmi bios_date)" | xargs)"
        printf 'boot: %s\n' "$(_boot_mode)"
        printf 'virtualization: %s\n' "$(systemd-detect-virt 2>/dev/null || true)"
        printf 'cpu: %s (%s threads)\n' \
            "$(awk -F': ' '/^model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null)" "$(nproc 2>/dev/null)"
        printf 'memory: %s\n' "$(awk '/^MemTotal:/ { printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo 2>/dev/null)"
        command -v lspci >/dev/null 2>&1 && _gpus
        command -v glxinfo >/dev/null 2>&1 \
            && printf 'renderer: %s\n' "$(timeout "$BUG_REPORT_TIMEOUT" glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer string/ { print $2; exit }')"
        printf 'graphics-packages: %s\n' "$(pacman -Q mesa nvidia-utils 2>/dev/null | tr '\n' ' ' | xargs)"
        if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
            timeout "$BUG_REPORT_TIMEOUT" hyprctl monitors -j 2>/dev/null | jq -r '.[] |
                "display: \(.make) \(.model) \(.width)x\(.height)@\(.refreshRate | floor)Hz scale \(.scale)\(if .vrr then " VRR" else "" end)"' 2>/dev/null || true
        fi
        printf 'root-filesystem: %s\n' "$(findmnt -no FSTYPE / 2>/dev/null)"
        printf 'audio-server: %s\n' "$(pactl info 2>/dev/null | awk -F': ' '/^Server Name/ { print $2; exit }')"
        if [ -e /var/log/modern-calamares-late.log ]; then
            printf 'installed-with: ISO installer\n'
        else
            printf 'installed-with: install.sh\n'
        fi
    } >"$f" 2>/dev/null
    return 0
}

_collect_hardware() {
    _grab hardware.txt lspci -k
    _grab hardware.txt lsusb
    _grab hardware.txt free -h
    _grab hardware.txt df -h -x tmpfs -x devtmpfs
    _grab hardware.txt pacman -Q "${BUG_REPORT_PACKAGES[@]}"
    _grab hardware.txt nvidia-smi --query-gpu=name,driver_version,memory.used,memory.total,temperature.gpu --format=csv
    # Renderer and driver only; vulkaninfo would add device UUIDs.
    _grab hardware.txt glxinfo -B
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
