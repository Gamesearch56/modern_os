#!/usr/bin/env bash
# Live ISO only: greetd autologins liveuser into cage + Calamares.
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
# ships the distro copy from the squashfs.
install -d -m 0755 /usr/share/i18n
printf '%s\n' 'en_US.UTF-8 UTF-8' 'de_DE.UTF-8 UTF-8' >/usr/share/i18n/SUPPORTED
printf '%s\n' 'en_US.UTF-8 UTF-8' 'de_DE.UTF-8 UTF-8' >/etc/locale.gen
locale-gen >/dev/null 2>&1 || true
if command -v python3 >/dev/null 2>&1; then
    python3 /usr/lib/modern/live-xkb-filter.py || true
fi

install -d -m 0755 /home/liveuser/.config/hypr /root/.config/hypr
ln -sfn /etc/modern/live-hyprland.lua /home/liveuser/.config/hypr/hyprland.lua
ln -sfn /etc/modern/live-hyprland.lua /root/.config/hypr/hyprland.lua
chown -R liveuser:liveuser /home/liveuser/.config
