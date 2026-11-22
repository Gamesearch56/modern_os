# shellcheck shell=bash
# Helpers for scripts/iso-release.sh: what a public ISO must not contain,
# and the download section of the GitHub release notes.

ISO_ASSET="modernos-x86_64.iso"
ISO_NOTES_START="<!-- modernos-iso -->"
ISO_NOTES_END="<!-- /modernos-iso -->"
# GitHub refuses release assets of 2 GiB or more.
# shellcheck disable=SC2034
ISO_ASSET_MAX=2147483648
# Credentials an image anyone can download must not carry. Paths are
# relative to the live root, as unsquashfs lists them.
ISO_LEAK_PATTERN='(/\.ssh/id_|/id_(rsa|dsa|ecdsa|ed25519)$|/secrets\.json$|/secrets/|deploy_key$|github-deploy-key|/\.gnupg/private-keys|/\.git-credentials$|/\.netrc$|/gh/hosts\.yml$)'

# Prints every credential-looking path in the ISO's live root. Returns 2
# when the image has no readable airootfs.sfs, so "no output" always
# means "looked and found nothing".
iso_leaks() {
    local iso="$1" lba listing
    lba="$(xorriso -indev "$iso" -find /arch/x86_64/airootfs.sfs -exec report_lba -- 2>/dev/null \
        | awk -F, '/^File data lba:/ { gsub(/ /, "", $2); print $2; exit }')" || true
    [[ "$lba" =~ ^[0-9]+$ ]] || return 2
    listing="$(unsquashfs -o $((lba * 2048)) -lc "$iso" 2>/dev/null)" || return 2
    [ -n "$listing" ] || return 2
    printf '%s\n' "$listing" | sed 's|^squashfs-root||' | grep -E "$ISO_LEAK_PATTERN" || true
}

# Release notes from stdin, then the download section. An older section
# is dropped wherever it sat, so a re-run moves it instead of stacking.
iso_notes_with_download() {
    local block="$1"
    awk -v start="$ISO_NOTES_START" -v end="$ISO_NOTES_END" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        skip { next }
        /^[[:space:]]*$/ { if (seen) blank++; next }
        { for (; blank > 0; blank--) print ""; seen = 1; print }'
    printf '\n%s\n' "$block"
}

# The download section for one release. Backticks are markdown code.
# shellcheck disable=SC2016
iso_download_block() {
    local web="$1" tag="$2" size="$3" sha="$4" fpr="$5" base
    base="$web/releases/download/$tag"
    printf '%s\n' "$ISO_NOTES_START"
    printf '### Download\n\n'
    printf '**[%s](%s/%s)** (%s) · [SHA256SUMS](%s/SHA256SUMS) · [signature](%s/SHA256SUMS.asc)\n\n' \
        "$ISO_ASSET" "$base" "$ISO_ASSET" \
        "$(awk -v b="$size" 'BEGIN { printf "%.2f GiB", b / 1073741824 }')" "$base" "$base"
    printf 'SHA-256 `%s`\n\n' "$sha"
    printf 'Check the image, then the signature with the [release key](%s/blob/main/docs/release-key.asc) (`%s`):\n\n' \
        "$web" "$fpr"
    printf '```sh\nsha256sum -c SHA256SUMS\ngpg --import release-key.asc\ngpg --verify SHA256SUMS.asc SHA256SUMS\n```\n'
    printf '%s\n' "$ISO_NOTES_END"
}
