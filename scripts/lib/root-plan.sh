#!/usr/bin/env bash
# Parses the root plan install.sh writes for a terminal-less update
# (see install/lib/pkg.sh defer_native). Source; needs pkg-name.sh.
#
# Sets ROOT_PLAN_PKGS (array) and ROOT_PLAN_GREETD (0/1). The plan sits
# in the user's state dir and is read by root, so anything that is not a
# plain package name is dropped rather than handed to pacman.
read_root_plan() {
    local file="$1" kind name
    ROOT_PLAN_PKGS=()
    ROOT_PLAN_GREETD=0
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
        esac
    done <"$file"
}
