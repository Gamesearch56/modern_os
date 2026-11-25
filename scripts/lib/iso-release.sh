# shellcheck shell=bash
# Helpers for scripts/iso-release.sh: what a public ISO must not contain,
# and the download section of the GitHub release notes.

ISO_ASSET="modernos-x86_64.iso"
ISO_NOTES_START="<!-- modernos-iso -->"
ISO_NOTES_END="<!-- /modernos-iso -->"
# Only after the image is a release asset. The notes are published
# before the upload, and this sentence would point at a missing file.
ISO_INSTALL_LINE="New installations: download the ISO from this page."
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
# The new-installations sentence is inserted here, once, because this
# runs only after the image is attached.
iso_notes_with_download() {
    local block="$1"
    awk -v start="$ISO_NOTES_START" -v end="$ISO_NOTES_END" \
        -v line="$ISO_INSTALL_LINE" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        skip { next }
        # The sentence is printed again under Installed systems. Dropping
        # the copy here must not keep the blank line that sat above it,
        # or a second run adds a blank line.
        $0 == line { blank = 0; next }
        /^[[:space:]]*$/ { if (seen) blank++; next }
        {
            for (; blank > 0; blank--) print ""
            seen = 1
            print
            if ($0 ~ /^Installed systems:/) {
                print ""
                print line
            }
        }'
    printf '\n%s\n' "$block"
}

# A desktop session can show the password-style windows. A test or a
# plain terminal without a display cannot.
iso_ui_ready() {
    [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || return 1
    if command -v kdialog >/dev/null 2>&1 && command -v qdbus6 >/dev/null 2>&1; then
        return 0
    fi
    command -v zenity >/dev/null 2>&1
}

# One line from the user. A window when there is no terminal, like sudo -A.
iso_ask_line() {
    local prompt="$1" line=""
    if [ ! -t 0 ] && iso_ui_ready; then
        if command -v kdialog >/dev/null 2>&1; then
            kdialog --title "ModernOS" --inputbox "$prompt"
            return
        fi
        zenity --entry --title="ModernOS" --text="$prompt"
        return
    fi
    if [ -t 0 ]; then
        printf '%s\n' "$prompt" >&2
        IFS= read -r line
        printf '%s\n' "$line"
        return 0
    fi
    printf 'iso-release: ERROR: %s There is no terminal or window to ask.\n' "$prompt" >&2
    return 1
}

# A tiled progress dialog fills the screen. Ask Hyprland to float the
# versioned title before the window maps.
iso_progress_float() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    hyprctl eval 'hl.window_rule({ name = "modern-release-progress", match = { title = "^ModernOS v[0-9]" }, float = true, center = true, size = { 560, 180 } })' \
        >/dev/null 2>&1 || true
}

# kdialog's ref is "service path". zenity reads percentages on stdin.
# $1 is the line under the bar, $2 is the window title (ModernOS vX.Y.Z).
iso_progress_open() {
    local text="$1" title="${2:-ModernOS}"
    ISO_PROGRESS_REF=""
    ISO_PROGRESS_FIFO=""
    iso_ui_ready || return 0
    iso_progress_float
    if command -v kdialog >/dev/null 2>&1 && command -v qdbus6 >/dev/null 2>&1; then
        ISO_PROGRESS_REF="$(kdialog --title "$title" --progressbar "$text" 100)"
        return 0
    fi
    ISO_PROGRESS_FIFO="$(mktemp -u)"
    mkfifo "$ISO_PROGRESS_FIFO"
    zenity --progress --title="$title" --text="$text" --width=560 --height=120 \
        --auto-close --percentage=0 <"$ISO_PROGRESS_FIFO" &
    ISO_PROGRESS_REF="zenity:$!"
    exec 3>"$ISO_PROGRESS_FIFO"
}

iso_progress_set() {
    local pct="$1" svc path
    case "$pct" in
        ''|*[!0-9]*) return 0 ;;
    esac
    [ "$pct" -gt 100 ] && pct=100
    case "${ISO_PROGRESS_REF:-}" in
        "") return 0 ;;
        zenity:*) printf '%s\n' "$pct" >&3 || true ;;
        *)
            read -r svc path <<<"$ISO_PROGRESS_REF"
            qdbus6 "$svc" "$path" Set "" value "$pct" >/dev/null 2>&1 || true
            ;;
    esac
}

iso_progress_close() {
    local svc path
    case "${ISO_PROGRESS_REF:-}" in
        "") return 0 ;;
        zenity:*)
            printf '100\n' >&3 || true
            exec 3>&- || true
            wait "${ISO_PROGRESS_REF#zenity:}" 2>/dev/null || true
            rm -f "${ISO_PROGRESS_FIFO:-}"
            ;;
        *)
            read -r svc path <<<"$ISO_PROGRESS_REF"
            qdbus6 "$svc" "$path" close >/dev/null 2>&1 || true
            ;;
    esac
    ISO_PROGRESS_REF=""
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
