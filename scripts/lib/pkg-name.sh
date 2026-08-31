#!/usr/bin/env bash
# Shared pacman name allowlist. Source from scripts/, never execute.

valid_pkg_name() {
    local n="${1:-}"
    [[ "$n" =~ ^[a-z0-9][a-z0-9.+_-]*$ ]]
}

filter_pkg_names() {
    local n
    for n in "$@"; do
        if valid_pkg_name "$n"; then
            printf '%s\n' "$n"
        fi
    done
}
