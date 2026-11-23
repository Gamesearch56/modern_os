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
    # Version first: a full path would let /tmp/v0.8.1 beat ~/.cache/v0.8.3.
    # The same version then uses the file written last, so a local rebuild
    # of v0.8.10 is chosen over the release image of that same name.
    found="$(
        for base in "${candidates[@]}"; do
            ver="$(basename "$base")"
            ver="${ver#modernos-}"
            ver="${ver%-x86_64.iso}"
            printf '%s\t%s\t%s\n' "$ver" "$(stat -c '%Y' "$base")" "$base"
        done | sort -k1,1V -k2,2n | tail -n 1 | cut -f3-
    )"
    [ -n "$found" ] || return 1
    printf '%s\n' "$found"
}
