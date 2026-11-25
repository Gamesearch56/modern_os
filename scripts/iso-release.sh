#!/usr/bin/env bash
# Build the public ISO for a release tag and attach it to the GitHub
# Release, signed. The image stays on this machine and on GitHub.
# Proton Drive is not used unless --archive is passed. Every step can
# be re-run: a finished build or upload is checked and kept, not
# repeated. See docs/GIT.md "Release ISO".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/iso-release.sh
source "$ROOT/scripts/lib/iso-release.sh"

OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
KEY_FILE="$ROOT/docs/release-key.asc"
ARCHIVE=""
TAG=""
ISO=""
REBUILD=0
WITH_KEY=0
KEY_PATH=/usr/lib/modern/deploy_key

usage() {
    cat <<'EOF'
Usage: iso-release.sh vX.Y.Z [--iso FILE] [--rebuild] [--with-deploy-key]
                      [--archive REMOTE:PATH | --no-archive]

Run on a clean checkout of the tag, after its GitHub Release exists.
  1. sudo iso-build.sh --mkarchiso --public (skipped if the ISO is there)
  2. refuse the image if it holds a deploy key or other credential
  3. SHA256SUMS, signed with the key in docs/release-key.asc
  4. upload modernos-x86_64.iso, SHA256SUMS, SHA256SUMS.asc and check
     GitHub's SHA-256 of the upload; add a Download section to the notes

--with-deploy-key builds without --public and lets exactly the update
deploy key through step 2. A release image does not use this flag.

--archive REMOTE:PATH also copies the image there with rclone. It is
off unless that flag is passed. The stable asset name keeps this link
on the newest image:
  https://github.com/OWNER/REPO/releases/latest/download/modernos-x86_64.iso
EOF
}

log() { printf 'iso-release: %s\n' "$*" >&2; }
die() { printf 'iso-release: ERROR: %s\n' "$*" >&2; exit 1; }
ISO_PROGRESS_REF=""
release_cleanup() {
    iso_progress_close || true
    rm -f "${ring:-}" "${notes:-}"
}
trap release_cleanup EXIT

while [ $# -gt 0 ]; do
    case "$1" in
        --iso) ISO="${2:-}"; shift ;;
        --rebuild) REBUILD=1 ;;
        --with-deploy-key) WITH_KEY=1 ;;
        --archive) ARCHIVE="${2:-}"; shift ;;
        --no-archive) ARCHIVE="" ;;
        -h|--help) usage; exit 0 ;;
        v*) TAG="$1" ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "need a vX.Y.Z tag (got ${TAG:-nothing})"
for tool in gh gpg gpgv xorriso unsquashfs sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is missing"
done
[ -z "$ARCHIVE" ] || command -v rclone >/dev/null 2>&1 \
    || die "rclone is missing (pacman -S rclone), or pass --no-archive"

git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "$TAG is not a tag here"
[ "$(git -C "$ROOT" rev-parse HEAD)" = "$(git -C "$ROOT" rev-parse "$TAG^{commit}")" ] \
    || die "check out $TAG first (git checkout $TAG) so the live image matches the release"
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] \
    || die "the working tree has changes; the image would not be $TAG"

[ -f "$KEY_FILE" ] || die "no docs/release-key.asc — create the signing key first (docs/GIT.md)"
FPR="$(gpg --show-keys --with-colons "$KEY_FILE" 2>/dev/null | awk -F: '/^fpr:/ { print $10; exit }')"
[ -n "$FPR" ] || die "docs/release-key.asc holds no public key"
gpg --list-secret-keys "$FPR" >/dev/null 2>&1 || die "the secret key for $FPR is not in your keyring"

NWO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
WEB="https://github.com/$NWO"
gh release view "$TAG" >/dev/null 2>&1 || die "no GitHub Release $TAG yet — publish it first"
if [ "$(gh repo view --json visibility -q .visibility)" != PUBLIC ]; then
    log "WARNING: $NWO is private — the download link needs a GitHub login with access"
fi

# What is wrong with an image for this release, one line each; nothing
# when it may be uploaded.
image_problems() {
    local found
    found="$(iso_leaks "$1")" || { echo "the live root of $1 cannot be listed"; return 0; }
    if [ "$WITH_KEY" -eq 1 ]; then
        printf '%s\n' "$found" | grep -Fxq "$KEY_PATH" || echo "no deploy key at $KEY_PATH"
        found="$(printf '%s\n' "$found" | grep -Fxv "$KEY_PATH" || true)"
    fi
    [ -z "$found" ] || printf 'credential: %s\n' "$found"
}

# No terminal: sudo cannot read a password. -A asks a graphical helper
# instead, which is the password window.
release_sudo() {
    local askpass="" own=0 tool
    if [ -n "${SUDO_ASKPASS:-}" ] && [ -x "$SUDO_ASKPASS" ]; then
        askpass="$SUDO_ASKPASS"
    elif [ ! -t 0 ]; then
        if command -v kdialog >/dev/null 2>&1; then
            tool=kdialog
        elif command -v zenity >/dev/null 2>&1; then
            tool=zenity
        else
            die "sudo needs a password and there is no terminal or password window"
        fi
        askpass="$(mktemp)"
        own=1
        if [ "$tool" = kdialog ]; then
            cat >"$askpass" <<'EOF'
#!/bin/sh
# sudo may start this with a cleaned environment. Find the session
# so the password window can open.
uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
        [ -S "$sock" ] || continue
        WAYLAND_DISPLAY="${sock##*/}"
        export WAYLAND_DISPLAY
        break
    done
fi
exec kdialog --title "ModernOS" --password "${1:-Password:}"
EOF
        else
            cat >"$askpass" <<'EOF'
#!/bin/sh
uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
        [ -S "$sock" ] || continue
        WAYLAND_DISPLAY="${sock##*/}"
        export WAYLAND_DISPLAY
        break
    done
fi
exec zenity --password --title="ModernOS" --text="${1:-Password:}"
EOF
        fi
        chmod 700 "$askpass"
    fi
    if [ -n "$askpass" ]; then
        log "building the image (a window asks for your password once)"
        set +e
        SUDO_ASKPASS="$askpass" sudo -A "$@"
        local rc=$?
        set -e
        [ "$own" -eq 1 ] && rm -f "$askpass"
        return "$rc"
    fi
    log "building the image (sudo asks for your password once)"
    sudo "$@"
}

build_args=(--mkarchiso --tag "$TAG" --out "$OUT")
[ "$WITH_KEY" -eq 1 ] || build_args+=(--public)
if [ -z "$ISO" ]; then
    ISO="$OUT/modernos-$TAG-x86_64.iso"
    if [ "$REBUILD" -eq 1 ] || [ ! -f "$ISO" ] || [ -n "$(image_problems "$ISO")" ]; then
        release_sudo "$ROOT/scripts/iso-build.sh" "${build_args[@]}"
    else
        log "reusing $ISO (--rebuild to build it again)"
    fi
fi
[ -f "$ISO" ] || die "no image at $ISO"

problems="$(image_problems "$ISO")"
if [ -n "$problems" ]; then
    printf '  %s\n' "$problems" >&2
    die "$ISO cannot be released as it is (credentials need iso-build.sh --public)"
fi
if [ "$WITH_KEY" -eq 1 ]; then
    log "WARNING: the image carries the deploy key, as asked (--with-deploy-key)"
else
    log "no credentials in the live root"
fi

size="$(stat -c %s "$ISO")"
[ "$size" -lt "$ISO_ASSET_MAX" ] || die "image is $size bytes; GitHub takes under 2 GiB per asset"

STAGE="$OUT/release/$TAG"
mkdir -p "$STAGE"
ln -f "$ISO" "$STAGE/$ISO_ASSET" 2>/dev/null || cp --reflink=auto "$ISO" "$STAGE/$ISO_ASSET"
for extra in "$OUT/${TAG}-PACKAGES.txt" "$OUT/${TAG}-SOURCE-OFFER.txt"; do
    if [ -f "$extra" ]; then
        cp --reflink=auto "$extra" "$STAGE/"
    else
        log "WARNING: missing $(basename "$extra"); the source offer is not beside this image"
    fi
done
(cd "$STAGE" && sha256sum "$ISO_ASSET" >SHA256SUMS)
sha="$(cut -d' ' -f1 "$STAGE/SHA256SUMS")"
rm -f "$STAGE/SHA256SUMS.asc"
gpg --batch --yes --local-user "$FPR" --armor --detach-sign \
    --output "$STAGE/SHA256SUMS.asc" "$STAGE/SHA256SUMS"
ring="$(mktemp)"
gpg --dearmor <"$KEY_FILE" >"$ring"
gpgv --keyring "$ring" "$STAGE/SHA256SUMS.asc" "$STAGE/SHA256SUMS" 2>/dev/null \
    || die "the signature does not verify against docs/release-key.asc"
log "signed SHA256SUMS with $FPR"

remote_sha() {
    gh api "repos/$NWO/releases/tags/$TAG" \
        --jq ".assets[] | select(.name == \"$ISO_ASSET\") | .digest // \"none\"" 2>/dev/null || true
}

# curl's bar ends each update with a percentage. Feed that to the window.
release_curl_progress() {
    local line pct
    while IFS= read -r line; do
        pct="$(printf '%s\n' "$line" | grep -oE '[0-9]+\.[0-9]+' | tail -1 || true)"
        [ -n "$pct" ] && iso_progress_set "${pct%%.*}"
    done
}

# Sums, and the source offer when this build wrote one.
release_upload_sums() {
    local extra=() f
    for f in "$STAGE/${TAG}-PACKAGES.txt" "$STAGE/${TAG}-SOURCE-OFFER.txt"; do
        [ -f "$f" ] && extra+=( "$f" )
    done
    gh release upload "$TAG" "$STAGE/SHA256SUMS" "$STAGE/SHA256SUMS.asc" "${extra[@]}" --clobber
}

# A window tracks the image. The sums are tiny and stay on gh.
release_upload_image() {
    local id token url rc=0 extra=() f
    if ! iso_ui_ready; then
        for f in "$STAGE/${TAG}-PACKAGES.txt" "$STAGE/${TAG}-SOURCE-OFFER.txt"; do
            [ -f "$f" ] && extra+=( "$f" )
        done
        gh release upload "$TAG" "$STAGE/$ISO_ASSET" "$STAGE/SHA256SUMS" "$STAGE/SHA256SUMS.asc" \
            "${extra[@]}" --clobber
        return
    fi
    id="$(gh api "repos/$NWO/releases/tags/$TAG" --jq .id)"
    token="$(gh auth token)"
    [ -n "$id" ] && [ -n "$token" ] || die "could not start the image upload"
    gh release delete-asset "$TAG" "$ISO_ASSET" --yes >/dev/null 2>&1 || true
    url="https://uploads.github.com/repos/${NWO}/releases/${id}/assets?name=${ISO_ASSET}"
    log "uploading $(awk -v b="$size" 'BEGIN { printf "%.2f GiB", b / 1073741824 }')"
    iso_progress_open "Uploading the release image" "ModernOS ${TAG}"
    set +e
    curl --progress-bar -f -S -T "$STAGE/$ISO_ASSET" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/octet-stream" \
        -H "Accept: application/vnd.github+json" \
        -o "$STAGE/upload-response.json" \
        "$url" 2> >(tr '\r' '\n' | release_curl_progress)
    rc=$?
    set -e
    iso_progress_close
    rm -f "$STAGE/upload-response.json"
    [ "$rc" -eq 0 ] || die "the image upload did not finish"
    release_upload_sums
}

if [ "$(remote_sha)" = "sha256:$sha" ]; then
    log "GitHub already has this image"
    release_upload_sums
else
    release_upload_image
    got="$(remote_sha)"
    case "$got" in
        "sha256:$sha") log "GitHub's SHA-256 matches" ;;
        none|"") log "WARNING: GitHub reports no digest; only the size was checked" ;;
        *) die "GitHub has $got for the upload, expected sha256:$sha — run again" ;;
    esac
fi

notes="$(mktemp)"
gh release view "$TAG" --json body -q .body \
    | iso_notes_with_download "$(iso_download_block "$WEB" "$TAG" "$size" "$sha" "$FPR")" >"$notes"
gh release edit "$TAG" --notes-file "$notes" >/dev/null
log "release notes link the image: $WEB/releases/tag/$TAG"

# One rclone copy. Percentages from its stats line move the window.
# The exit status is rclone's, not the parser's.
release_rclone_copy() {
    local dest="$1" extra=() rc=0
    if [ -n "${2:-}" ]; then
        extra=(--protondrive-2fa "$2")
    fi
    iso_progress_open "Saving the release image" "ModernOS ${TAG}"
    set +e
    rclone copy "${extra[@]}" "$STAGE" "$dest" --stats 1s --stats-one-line 2>&1 \
        | tr '\r' '\n' | while IFS= read -r line; do
            printf '%s\n' "$line" >>"$ARCHIVE_LOG"
            pct="$(printf '%s\n' "$line" | grep -oE '[0-9]+%' | tail -1 || true)"
            [ -n "$pct" ] && iso_progress_set "${pct%%%}"
        done
    rc=${PIPESTATUS[0]}
    set -e
    iso_progress_close
    return "$rc"
}

release_archive() {
    local dest rc=0 code=""
    dest="${ARCHIVE%/}/$TAG"
    log "archiving to $dest"
    ARCHIVE_LOG="$(mktemp)"
    release_rclone_copy "$dest" || rc=$?
    if [ "$rc" -ne 0 ] && grep -Eiq '2fa|two-factor|two factor|totp' "$ARCHIVE_LOG"; then
        if grep -Eiq 'too many requests|rate limit|HTTP 429' "$ARCHIVE_LOG"; then
            rm -f "$ARCHIVE_LOG"
            die "Proton is limiting logins. Wait a few minutes, then run this again."
        fi
        code="$(iso_ask_line "Proton needs a two-factor code to save this release.")" || {
            rm -f "$ARCHIVE_LOG"
            die "Proton needs a two-factor code"
        }
        [ -n "$code" ] || { rm -f "$ARCHIVE_LOG"; die "Proton needs a two-factor code"; }
        : >"$ARCHIVE_LOG"
        rc=0
        release_rclone_copy "$dest" "$code" || rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        cat "$ARCHIVE_LOG" >&2
        rm -f "$ARCHIVE_LOG"
        die "the archive copy at $dest did not finish — run again"
    fi
    rm -f "$ARCHIVE_LOG"
    rclone check --one-way "$STAGE" "$dest" || die "the archive copy at $dest does not match — run again"
    log "archive matches"
}

if [ -n "$ARCHIVE" ]; then
    release_archive
else
    log "GitHub has the image; no archive copy"
fi
log "done: $WEB/releases/latest/download/$ISO_ASSET"
