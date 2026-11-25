#!/usr/bin/env bash
# Source only. mkdir -p exits "File exists" when any component is a
# dangling symlink, and a wallpaper change then stops before the icon
# theme is written. A link that still points somewhere is left alone,
# and a real file is never replaced.
ensure_real_dir() {
    local dir="${1:-}" cur="" piece rest
    [ -n "$dir" ] || return 1
    case "$dir" in
        /*) ;;
        *) return 1 ;;
    esac
    rest="${dir#/}"
    while [ -n "$rest" ]; do
        piece="${rest%%/*}"
        if [ "$piece" = "$rest" ]; then
            rest=""
        else
            rest="${rest#*/}"
        fi
        [ -n "$piece" ] || continue
        cur="${cur}/${piece}"
        if [ -L "$cur" ] && [ ! -e "$cur" ]; then
            rm -f -- "$cur"
        fi
        if [ -e "$cur" ] && [ ! -d "$cur" ]; then
            printf 'ensure_real_dir: %s is not a directory\n' "$cur" >&2
            return 1
        fi
        if [ ! -d "$cur" ]; then
            mkdir -- "$cur" || return 1
        fi
    done
}
