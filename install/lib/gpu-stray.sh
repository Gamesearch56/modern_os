#!/usr/bin/env bash
# NVIDIA userspace on a computer without an NVIDIA GPU. Earlier installers
# let pacman pick lib32-nvidia-utils for Steam's lib32-vulkan-driver, which
# pulls nvidia-utils; its EGL vendor library then fails eglQueryDevicesEXT
# with EGL_BAD_ALLOC on every compositor start. Source, never execute.
# Needs log.sh and ui.sh for prune_stray_nvidia; root (update-apply.sh)
# only calls stray_nvidia_packages.

# Every PCI display device, not just the first: a hybrid laptop lists the
# Intel GPU before the NVIDIA one.
nvidia_gpu_present() {
    local dev
    for dev in "${MODERN_SYSFS_PCI:-/sys/bus/pci/devices}"/*; do
        [ "$(cat "$dev/vendor" 2>/dev/null)" = 0x10de ] || continue
        case "$(cat "$dev/class" 2>/dev/null)" in
            0x03*) return 0 ;;
        esac
    done
    return 1
}

# Prints the installed NVIDIA userspace packages that have no GPU to drive.
# Nothing when an NVIDIA GPU or an NVIDIA kernel module package is present:
# that driver was chosen on purpose (an eGPU, a card swapped out for now).
stray_nvidia_packages() {
    local p
    nvidia_gpu_present && return 0
    for p in nvidia nvidia-open nvidia-dkms nvidia-open-dkms nvidia-lts nvidia-open-lts; do
        pacman -Q "$p" >/dev/null 2>&1 && return 0
    done
    for p in lib32-nvidia-utils nvidia-utils; do
        if pacman -Q "$p" >/dev/null 2>&1; then
            printf '%s\n' "$p"
        fi
    done
    return 0
}

# Runs after install_native, so Steam's own 32-bit driver for this GPU is
# already in place. pacman refuses when anything else still needs them.
prune_stray_nvidia() {
    local stray=()
    [ "${DOTFILES_ONLY:-0}" -eq 1 ] && return 0
    mapfile -t stray < <(stray_nvidia_packages)
    [ ${#stray[@]} -gt 0 ] || return 0
    if [ -n "${MODERN_ROOT_PLAN:-}" ] && [ "${DRY_RUN:-0}" -eq 0 ]; then
        printf 'nvidia-stray\n' >>"$MODERN_ROOT_PLAN"
        log_info "deferred removing ${stray[*]} (no NVIDIA GPU) to the update's root step"
        return 0
    fi
    log_info "Removing ${stray[*]}: this computer has no NVIDIA GPU"
    run sudo pacman -Rn --noconfirm "${stray[@]}" \
        || log_warn "kept ${stray[*]}: another package still needs it"
}
