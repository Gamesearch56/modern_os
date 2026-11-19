#!/usr/bin/env bash
# GATED — sourced by provision-iso.sh in a Calamares chroot only.
# NVIDIA modeset + initramfs. Gated; not applied by install.sh.
set -euo pipefail

nvidia_apply() {
    local root="${1:-/}"
    local src="${PROVISION_ROOT:?}/install/system/nvidia/modern-nvidia.conf"
    local dest="${root%/}/etc/modprobe.d/modern-nvidia.conf"
    [ -f "$src" ] || return 1
    install -d -m 0755 "${root%/}/etc/modprobe.d"
    install -m 0644 "$src" "$dest"

    local cmdline="${root%/}/etc/kernel/cmdline"
    if [ -f "$cmdline" ]; then
        if ! grep -q 'nvidia-drm.modeset=1' "$cmdline"; then
            printf ' nvidia-drm.modeset=1 nvidia-drm.fbdev=1' >>"$cmdline"
        fi
    else
        install -d -m 0755 "${root%/}/etc/kernel"
        printf 'nvidia-drm.modeset=1 nvidia-drm.fbdev=1\n' >"${root%/}/etc/kernel/cmdline"
    fi

    local mk="${root%/}/etc/mkinitcpio.conf"
    if [ -f "$mk" ] && ! grep -q 'nvidia_drm' "$mk"; then
        sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$mk"
    fi
    # provision-iso.sh rebuilds the initramfs once, after the splash hook.
}
