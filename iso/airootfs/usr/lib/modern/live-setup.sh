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
# installer-locales.json (same file as Welcome languages and xkb).
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

# Wi-Fi in Calamares uses nmcli. archiso releng also ships iwd; both
# cannot own the same radio. NM starts iwd as its wifi backend
# (conf.d/wifi-backend.conf). Leave systemd-networkd for wired DHCP so
# QEMU still has a default route without NetworkManager claiming the NIC.
systemctl enable --now NetworkManager.service
systemctl disable --now iwd.service 2>/dev/null || true
systemctl stop iwd.service 2>/dev/null || true
