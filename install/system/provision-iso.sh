#!/usr/bin/env bash
# GATED — Calamares late / friend chroot only. Enables greetd, NetworkManager,
# bluetooth. Never run on the development PC. See docs/ISOLATION.md.
#
# Usage: MODERN_ISO_PROVISION=1 provision-iso.sh <username>
set -euo pipefail

PROVISION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROVISION_ROOT

die() { printf 'provision-iso: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'provision-iso: %s\n' "$*"; }

USERNAME="${1:-}"
[ -n "$USERNAME" ] || die "usage: $0 <username>"
id "$USERNAME" >/dev/null 2>&1 || die "user $USERNAME does not exist"

if [ -d /home/bastianweigand ]; then
    die "refusing to run on the development PC (/home/bastianweigand exists)"
fi
if [ "${MODERN_ISO_PROVISION:-}" != "1" ]; then
    die "refusing to run without MODERN_ISO_PROVISION=1 (Calamares late only)"
fi
if [ "$(id -u)" -ne 0 ]; then
    die "run as root in the install target"
fi

# shellcheck source=nvidia/apply.sh
source "$PROVISION_ROOT/install/system/nvidia/apply.sh"

log "enabling NetworkManager bluetooth greetd systemd-timesyncd"
systemctl enable NetworkManager bluetooth greetd systemd-timesyncd
systemctl set-default graphical.target

install -d -m 0755 /etc/greetd
install -m 0644 "$PROVISION_ROOT/install/system/greetd/config.toml" /etc/greetd/config.toml
install -m 0644 "$PROVISION_ROOT/install/system/greetd/hyprland.conf" /etc/greetd/hyprland.conf

if ! getent group modern >/dev/null 2>&1; then
    groupadd --system modern
fi
if ! id greeter >/dev/null 2>&1; then
    useradd --system --create-home --home-dir /var/lib/greeter \
        --shell /usr/bin/nologin --gid modern -G video,seat greeter || true
fi
if [ -f "$PROVISION_ROOT/install/system/tmpfiles.d/modern-session.conf" ]; then
    install -m 0644 "$PROVISION_ROOT/install/system/tmpfiles.d/modern-session.conf" \
        /etc/tmpfiles.d/modern-session.conf
    systemd-tmpfiles --create /etc/tmpfiles.d/modern-session.conf || true
fi

GREETER_HOME="$(getent passwd greeter | cut -d: -f6)"
if [ -n "$GREETER_HOME" ] && [ -d "$PROVISION_ROOT/stow/greeter" ]; then
    install -d -m 0755 "$GREETER_HOME/.config/quickshell"
    rm -rf "$GREETER_HOME/.config/quickshell/greeter"
    cp -a "$PROVISION_ROOT/stow/greeter/.config/quickshell/greeter" \
        "$GREETER_HOME/.config/quickshell/greeter"
    chown -R greeter:modern "$GREETER_HOME/.config" || true
fi

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
wp="${USER_HOME}/.config/modern/wallpapers/default.jpg"
if [ -x "$PROVISION_ROOT/scripts/wallpaper-sync.sh" ] && [ -f "$wp" ]; then
    sudo -u "$USERNAME" env \
        HOME="$USER_HOME" \
        XDG_STATE_HOME="${USER_HOME}/.local/state" \
        bash "$PROVISION_ROOT/scripts/wallpaper-sync.sh" "$wp" || true
fi
install -d -m 2775 /var/lib/modern/session
printf '%s\n' "$USERNAME" >/var/lib/modern/session/default-user
chown root:modern /var/lib/modern/session/default-user || true
chmod 0644 /var/lib/modern/session/default-user

for g in wheel video input audio render seat i2c; do
    if getent group "$g" >/dev/null 2>&1; then
        usermod -aG "$g" "$USERNAME" || true
    fi
done

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$USERNAME" || true
fi

gpu="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA compatible controller|3D controller/{print; exit}')"
if printf '%s' "$gpu" | grep -qi nvidia; then
    log "NVIDIA GPU — applying modeset and initramfs modules"
    nvidia_apply /
else
    log "non-NVIDIA GPU — skipping NVIDIA drop-ins"
fi

rm -f /etc/sudoers.d/99-modern-calamares
log "provision complete for $USERNAME"
