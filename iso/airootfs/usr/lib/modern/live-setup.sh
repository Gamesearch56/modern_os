#!/usr/bin/env bash
# Live ISO only: greetd autologins this user into Hyprland + Calamares.
set -euo pipefail

if ! id liveuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash -c "ModernOS live" liveuser
fi
for g in wheel video audio input render storage optical; do
    if getent group "$g" >/dev/null 2>&1; then
        usermod -aG "$g" liveuser || true
    fi
done
passwd -d liveuser >/dev/null 2>&1 || true
install -d -m 0755 /home/liveuser/.config/hypr
ln -sfn /etc/modern/live-hyprland.lua /home/liveuser/.config/hypr/hyprland.lua
chown -R liveuser:liveuser /home/liveuser/.config
