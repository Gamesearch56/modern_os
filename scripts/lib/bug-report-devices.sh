#!/usr/bin/env bash
# Hardware, device and games collectors for scripts/bug-report.sh,
# sourced by bug-report-collect.sh (which defines _grab and _copy).

# Driver stacks that decide most display and game bugs; pacman -Q also
# names the ones that are missing.
BUG_REPORT_PACKAGES=(linux linux-zen linux-lts hyprland quickshell aquamarine mesa
    vulkan-radeon vulkan-intel nvidia nvidia-open nvidia-open-dkms nvidia-utils
    pipewire wireplumber bluez networkmanager)

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
