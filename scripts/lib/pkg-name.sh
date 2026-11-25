#!/usr/bin/env bash
# Shared pacman name allowlist. Source from scripts/, never execute.

PKG_NAME_MAX=64

valid_pkg_name() {
    local n="${1:-}"
    [[ ${#n} -ge 1 && ${#n} -le ${PKG_NAME_MAX} && "$n" =~ ^[a-z0-9][a-z0-9.+_-]*$ ]]
}

# Names pacman HoldPkg does not fully cover. Removing these bricks the
# machine or this desktop session. Install is still allowed.
protected_pkg() {
    local n="${1:-}"
    case "$n" in
        pacman | pacman-mirrorlist | archlinux-keyring | glibc | gcc-libs | \
        filesystem | linux | linux-lts | linux-zen | linux-firmware | \
        systemd | systemd-libs | dbus | util-linux | coreutils | bash | \
        shadow | sudo | polkit | base | hyprland | quickshell | \
        grub | lvm2 | cryptsetup)
            return 0
            ;;
    esac
    return 1
}

filter_pkg_names() {
    local n
    for n in "$@"; do
        if valid_pkg_name "$n"; then
            printf '%s\n' "$n"
        fi
    done
}
