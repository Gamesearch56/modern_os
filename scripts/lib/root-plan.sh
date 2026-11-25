#!/usr/bin/env bash
# Parses the root plan install.sh writes for a terminal-less update
# (see install/lib/pkg.sh defer_native). Source; needs pkg-name.sh.
#
# Sets ROOT_PLAN_PKGS (array), ROOT_PLAN_GREETD (0/1),
# ROOT_PLAN_SPLASH (0/1), ROOT_PLAN_MIRRORS (0/1), ROOT_PLAN_PORTAL (0/1)
# and ROOT_PLAN_NVIDIA_STRAY (0/1). The plan sits in
# the user's state dir and is read by root, so anything that is not a
# plain package name or one of those steps is dropped rather than
# handed to pacman.
# Callers read those variables; this file only writes them.
# shellcheck disable=SC2034

# Root (pkexec) must only read a plan the calling user owns, under that
# home. Tests call read_root_plan without this check.
assert_root_plan_file() {
    local file="$1" uid owner home resolved hp
    [ -n "$file" ] || return 0
    [ "$(id -u)" -eq 0 ] || return 0
    uid="${PKEXEC_UID:-${SUDO_UID:-}}"
    [ -n "$uid" ] && [ "$uid" != "0" ] || return 0
    [ -e "$file" ] || return 0
    [ ! -L "$file" ] || {
        printf 'root-plan: refusing symlink %q\n' "$file" >&2
        return 1
    }
    [ -f "$file" ] || return 1
    owner="$(stat -c '%u' -- "$file" 2>/dev/null || true)"
    [ "$owner" = "$uid" ] || {
        printf 'root-plan: owner %s is not the calling uid %s\n' "$owner" "$uid" >&2
        return 1
    }
    home="$(getent passwd "$uid" | cut -d: -f6 || true)"
    hp="$(readlink -f -- "$home" 2>/dev/null || true)"
    resolved="$(readlink -f -- "$file" 2>/dev/null || true)"
    [ -n "$hp" ] && [ -n "$resolved" ] || return 1
    case "$resolved" in
        "$hp"/.local/state/modern|"$hp"/.local/state/modern/*) return 0 ;;
    esac
    printf 'root-plan: refusing path outside the caller state dir\n' >&2
    return 1
}

# The file chooser portal is the one package root installs from a file:
# modern-portal.pkg.tar.zst in the caller's state dir, owned by the
# caller, not a symlink, and named modern-portal inside. Prints its path.
root_plan_portal_pkg() {
    local uid="${PKEXEC_UID:-${SUDO_UID:-}}" home file owner name
    [ -n "$uid" ] && [ "$uid" != "0" ] || return 1
    home="$(getent passwd "$uid" | cut -d: -f6 || true)"
    [ -n "$home" ] || return 1
    file="$home/.local/state/modern/packages/modern-portal.pkg.tar.zst"
    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    owner="$(stat -c '%u' -- "$file" 2>/dev/null || true)"
    [ "$owner" = "$uid" ] || return 1
    name="$(pacman -Qqp -- "$file" 2>/dev/null || true)"
    [ "$name" = "modern-portal" ] || return 1
    printf '%s\n' "$file"
}

read_root_plan() {
    local file="$1" kind name
    ROOT_PLAN_PKGS=()
    ROOT_PLAN_GREETD=0
    ROOT_PLAN_SPLASH=0
    ROOT_PLAN_MIRRORS=0
    ROOT_PLAN_PORTAL=0
    ROOT_PLAN_NVIDIA_STRAY=0
    [ -s "$file" ] || return 0
    while read -r kind name _; do
        case "$kind" in
            pkg)
                if valid_pkg_name "$name"; then
                    ROOT_PLAN_PKGS+=("$name")
                else
                    printf 'root-plan: ignoring invalid package %q\n' "$name" >&2
                fi
                ;;
            greetd) ROOT_PLAN_GREETD=1 ;;
            splash) ROOT_PLAN_SPLASH=1 ;;
            mirrors) ROOT_PLAN_MIRRORS=1 ;;
            portal) ROOT_PLAN_PORTAL=1 ;;
            nvidia-stray) ROOT_PLAN_NVIDIA_STRAY=1 ;;
        esac
    done <"$file"
}
