# shellcheck shell=bash
# Newest modernos-v*-x86_64.iso already on this computer.
# $1 repo root, $2 optional extra directory (iso-qemu's MODERN_ISO_OUT).

iso_newest_release() {
    local root="$1" extra="${2:-}" cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    local -a globs=() candidates=()
    local found="" base ver
    shopt -s nullglob
    globs=(
        "$root"/modernos-v*-x86_64.iso
        "$root"/iso/out/modernos-v*-x86_64.iso
        "$root"/iso/out/release/*/modernos-v*-x86_64.iso
        "$cache"/modern-v*/iso/out/modernos-v*-x86_64.iso
        "$HOME/.cache"/modern-v*/iso/out/modernos-v*-x86_64.iso
        /tmp/modern-v*/iso/out/modernos-v*-x86_64.iso
    )
    if [ -n "$extra" ]; then
        globs+=("$extra"/modernos-v*-x86_64.iso)
    fi
    candidates=("${globs[@]}")
    shopt -u nullglob
    [ "${#candidates[@]}" -gt 0 ] || return 1
    # Sort the version in the file name. A full path would let /tmp/v0.8.1
    # beat ~/.cache/v0.8.3.
    found="$(
        for base in "${candidates[@]}"; do
            ver="$(basename "$base")"
            ver="${ver#modernos-}"
            ver="${ver%-x86_64.iso}"
            printf '%s\t%s\n' "$ver" "$base"
        done | sort -V | tail -n 1 | cut -f2-
    )"
    [ -n "$found" ] || return 1
    printf '%s\n' "$found"
}
