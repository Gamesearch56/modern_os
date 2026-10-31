#!/usr/bin/env bash
# Live ISO only: greetd autologins liveuser into cage + Calamares.
# locale-gen and the xkb filter run from modern-live-i18n.service so they
# do not block the kiosk on a black VT.
set -euo pipefail

if ! id liveuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash -c "ModernOS live" liveuser
fi
for g in wheel video audio input render storage optical uucp; do
    if getent group "$g" >/dev/null 2>&1; then
        usermod -aG "$g" liveuser || true
    fi
done
passwd -d liveuser >/dev/null 2>&1 || true

# Calamares loadLocales() prefers this file over locale.gen and would
# otherwise offer every glibc locale. Overlay only — unpackfs still
# ships the distro copy from the squashfs. Lines come from
# installer-locales.json `locales` (Welcome languages). Keyboard layouts
# are a separate `layouts` key in that file.
install -d -m 0755 /usr/share/i18n
python3 - <<'PY'
import json
from pathlib import Path

paths = (
    Path("/usr/lib/modern/installer-locales.json"),
    Path("/etc/modern/installer-locales.json"),
)
data = None
for p in paths:
    if p.is_file():
        data = json.loads(p.read_text(encoding="utf-8"))
        break
if not data:
    raise SystemExit("live-setup: missing installer-locales.json")
lines = []
for loc in data.get("locales") or []:
    glibc = str(loc.get("glibc") or "").strip()
    if glibc:
        lines.append(f"{glibc} UTF-8")
if not lines:
    raise SystemExit("live-setup: installer-locales.json has no glibc entries")
text = "\n".join(lines) + "\n"
Path("/usr/share/i18n/SUPPORTED").write_text(text, encoding="utf-8")
Path("/etc/locale.gen").write_text(text, encoding="utf-8")
PY

install -d -m 0755 /home/liveuser/.config/hypr /root/.config/hypr
ln -sfn /etc/modern/live-hyprland.lua /home/liveuser/.config/hypr/hyprland.lua
ln -sfn /etc/modern/live-hyprland.lua /root/.config/hypr/hyprland.lua
chown -R liveuser:liveuser /home/liveuser/.config

# Wi-Fi in Calamares uses nmcli. The live image keeps NetworkManager on
# wpa_supplicant (the same backend the installed desktop uses). archiso
# enables iwd and a networkd .network for every wlan device. iwd is a
# D-Bus service, so stopping it is not enough: the next lookup starts it
# again and it keeps the radio. networkctl reload does not drop a link
# networkd already configured, so the interface stays out of NM and
# `nmcli device wifi list` prints no names. Mask iwd, release those
# links, then bring them back up: a link left administratively down
# scans as an empty list, which is what Settings does not do after
# install. Leave networkd for wired DHCP so QEMU still has a default
# route without NetworkManager claiming the NIC.
# wl replaces the in-tree driver only for the PCI ids that need it, and
# that new interface has to exist before the down/up pass below.
/usr/lib/modern/live-wifi-wl.sh || true
rm -f /etc/systemd/network/20-wlan.network /etc/systemd/network/20-wwan.network
if [ -d /sys/class/net ]; then
    for nic in /sys/class/net/*; do
        [ -d "$nic/wireless" ] || [ -d "$nic/phy80211" ] || continue
        name="${nic##*/}"
        networkctl down "$name" 2>/dev/null || true
        ip link set "$name" down 2>/dev/null || true
    done
fi
networkctl reload 2>/dev/null || true
systemctl mask --now iwd.service 2>/dev/null || true
rfkill unblock wifi 2>/dev/null || true
systemctl enable --now NetworkManager.service
nmcli radio wifi on >/dev/null 2>&1 || true
# networkctl down clears IFF_UP. NM will not scan a down radio, so the
# Network step stays on "No networks found" until something brings it up.
bring_wifi_up() {
    local nic name
    [ -d /sys/class/net ] || return 0
    for nic in /sys/class/net/*; do
        [ -d "$nic/wireless" ] || [ -d "$nic/phy80211" ] || continue
        name="${nic##*/}"
        nmcli device set "$name" managed yes >/dev/null 2>&1 || true
        ip link set "$name" up 2>/dev/null || true
    done
}
# The radio can appear after firmware loads. One early scan then stays
# empty, and the installer reads that empty cache.
for _ in 1 2 3 4 5; do
    bring_wifi_up
    nmcli -w 15 device wifi list --rescan yes >/dev/null 2>&1 || true
    if nmcli -t -f SSID device wifi list 2>/dev/null | grep -q .; then
        break
    fi
    sleep 2
done

# QEMU has no 802.11 device. iso-qemu.sh --wifi-sim sets this fw_cfg and
# omits the virtio NIC so the Network step shows Wi-Fi instead of Ethernet.
if [ -r /sys/firmware/qemu_fw_cfg/by_name/opt/org.modernos/wifi-sim/raw ]; then
    /usr/lib/modern/live-wifi-sim.sh || true
fi

# Calamares reads unpackfs.conf when it starts, not when the job runs.
# archiso leaves airootfs.sfs on the stick, or under copytoram after the
# "copy to RAM" boot entry unmounts the stick. A single hardcoded path
# then fails with "source filesystem does not exist".
pin_unpackfs_source() {
    local found="" f back conf fs
    local -a candidates=()
    shopt -s nullglob
    candidates=(
        /run/archiso/bootmnt/*/x86_64/airootfs.sfs
        /run/archiso/bootmnt/*/x86_64/airootfs.erofs
        /run/archiso/copytoram/airootfs.sfs
        /run/archiso/copytoram/airootfs.erofs
    )
    shopt -u nullglob
    for f in "${candidates[@]}"; do
        if [ -f "$f" ]; then
            found=$f
            break
        fi
    done
    if [ -z "$found" ]; then
        found="$(find /run/archiso -type f \( -name 'airootfs.sfs' -o -name 'airootfs.erofs' \) -print -quit 2>/dev/null || true)"
    fi
    if [ -z "$found" ] && command -v losetup >/dev/null 2>&1; then
        while IFS= read -r back; do
            back="${back%% (deleted)}"
            if [ -n "$back" ] && [ -f "$back" ]; then
                found=$back
                break
            fi
        done < <(losetup -lnO BACK-FILE 2>/dev/null || true)
    fi
    if [ -z "$found" ]; then
        printf 'live-setup: airootfs image not found; unpackfs keeps its default path\n' >&2
        return 0
    fi
    fs=squashfs
    case "$found" in
        *.erofs) fs=erofs ;;
    esac
    conf=/etc/calamares/modules/unpackfs.conf
    if [ ! -f "$conf" ]; then
        printf 'live-setup: missing %s\n' "$conf" >&2
        return 0
    fi
    python3 - "$conf" "$found" "$fs" <<'PY'
import sys
path, src, fs = sys.argv[1:]
lines = open(path, encoding="utf-8").read().splitlines(True)
out = []
for line in lines:
    if line.startswith("  - source:"):
        out.append(f'  - source: "{src}"\n')
    elif line.startswith("    sourcefs:"):
        out.append(f'    sourcefs: "{fs}"\n')
    else:
        out.append(line)
open(path, "w", encoding="utf-8").write("".join(out))
PY
    printf 'live-setup: unpackfs will read %s\n' "$found"
}

pin_unpackfs_source
