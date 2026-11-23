# shellcheck shell=bash
# Newest ModernOS image already on this computer.
# $1 repo root, $2 optional extra directory (iso-qemu's MODERN_ISO_OUT).
# A release copy is iso/out/release/vX.Y.Z/modernos-x86_64.iso: the version
# is the folder, because the file name is the GitHub asset name.

iso_image_version() {
    local base="$1" name parent
    name="$(basename "$base")"
    if [ "$name" = "modernos-x86_64.iso" ]; then
        parent="$(basename "$(dirname "$base")")"
        printf '%s\n' "$parent"
        return 0
    fi
    name="${name#modernos-}"
    name="${name%-x86_64.iso}"
    printf '%s\n' "$name"
}

# What iso-write prints. A release copy is v0.8.11/modernos-x86_64.iso
# so the folder tells the version apart from the shared file name.
iso_image_label() {
    local base="$1" name parent
    name="$(basename "$base")"
    parent="$(basename "$(dirname "$base")")"
    if [ "$name" = "modernos-x86_64.iso" ] && [[ "$parent" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf '%s/%s\n' "$parent" "$name"
        return 0
    fi
    printf '%s\n' "$name"
}

iso_newest_release() {
    local root="$1" extra="${2:-}" cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    local -a globs=() candidates=()
    local found="" base ver
    shopt -s nullglob
    globs=(
        "$root"/modernos-v*-x86_64.iso
        "$root"/iso/out/modernos-v*-x86_64.iso
        "$root"/iso/out/release/v*/modernos-x86_64.iso
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
            ver="$(iso_image_version "$base")"
            printf '%s\t%s\t%s\n' "$ver" "$(stat -c '%Y' "$base")" "$base"
        done | sort -k1,1V -k2,2n | tail -n 1 | cut -f3-
    )"
    [ -n "$found" ] || return 1
    printf '%s\n' "$found"
}
