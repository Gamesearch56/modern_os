#!/usr/bin/env bash
# Build the public ISO for a release tag and attach it to the GitHub
# Release, signed, with an optional rclone archive copy (Proton Drive).
# Every step can be re-run: a finished build, upload or archive is
# checked and kept, not repeated. See docs/GIT.md "Release ISO".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/iso-release.sh
source "$ROOT/scripts/lib/iso-release.sh"

OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
KEY_FILE="$ROOT/docs/release-key.asc"
ARCHIVE="${MODERNOS_ISO_ARCHIVE:-}"
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
  5. rclone copy to REMOTE:PATH/vX.Y.Z and rclone check it

--with-deploy-key builds without --public and lets exactly the update
deploy key through step 2, so installs can read a private repo and open
the sealed bug-report token. Anyone holding the image holds both.

--archive defaults to $MODERNOS_ISO_ARCHIVE; without either, step 5 is
skipped. The stable asset name keeps this link on the newest image:
  https://github.com/OWNER/REPO/releases/latest/download/modernos-x86_64.iso
EOF
}

log() { printf 'iso-release: %s\n' "$*" >&2; }
die() { printf 'iso-release: ERROR: %s\n' "$*" >&2; exit 1; }

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

build_args=(--mkarchiso --tag "$TAG" --out "$OUT")
[ "$WITH_KEY" -eq 1 ] || build_args+=(--public)
if [ -z "$ISO" ]; then
    ISO="$OUT/modernos-$TAG-x86_64.iso"
    if [ "$REBUILD" -eq 1 ] || [ ! -f "$ISO" ] || [ -n "$(image_problems "$ISO")" ]; then
        log "building the image (sudo asks for your password once)"
        sudo ${SUDO_ASKPASS:+-A} "$ROOT/scripts/iso-build.sh" "${build_args[@]}"
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
(cd "$STAGE" && sha256sum "$ISO_ASSET" >SHA256SUMS)
sha="$(cut -d' ' -f1 "$STAGE/SHA256SUMS")"
rm -f "$STAGE/SHA256SUMS.asc"
gpg --batch --yes --local-user "$FPR" --armor --detach-sign \
    --output "$STAGE/SHA256SUMS.asc" "$STAGE/SHA256SUMS"
ring="$(mktemp)"
trap 'rm -f "$ring"' EXIT
gpg --dearmor <"$KEY_FILE" >"$ring"
gpgv --keyring "$ring" "$STAGE/SHA256SUMS.asc" "$STAGE/SHA256SUMS" 2>/dev/null \
    || die "the signature does not verify against docs/release-key.asc"
log "signed SHA256SUMS with $FPR"

remote_sha() {
    gh api "repos/$NWO/releases/tags/$TAG" \
        --jq ".assets[] | select(.name == \"$ISO_ASSET\") | .digest // \"none\"" 2>/dev/null || true
}
if [ "$(remote_sha)" = "sha256:$sha" ]; then
    log "GitHub already has this image"
    gh release upload "$TAG" "$STAGE/SHA256SUMS" "$STAGE/SHA256SUMS.asc" --clobber
else
    log "uploading $(awk -v b="$size" 'BEGIN { printf "%.2f GiB", b / 1073741824 }')"
    gh release upload "$TAG" "$STAGE/$ISO_ASSET" "$STAGE/SHA256SUMS" "$STAGE/SHA256SUMS.asc" --clobber
    got="$(remote_sha)"
    case "$got" in
        "sha256:$sha") log "GitHub's SHA-256 matches" ;;
        none|"") log "WARNING: GitHub reports no digest; only the size was checked" ;;
        *) die "GitHub has $got for the upload, expected sha256:$sha — run again" ;;
    esac
fi

notes="$(mktemp)"
trap 'rm -f "$ring" "$notes"' EXIT
gh release view "$TAG" --json body -q .body \
    | iso_notes_with_download "$(iso_download_block "$WEB" "$TAG" "$size" "$sha" "$FPR")" >"$notes"
gh release edit "$TAG" --notes-file "$notes" >/dev/null
log "release notes link the image: $WEB/releases/tag/$TAG"

if [ -n "$ARCHIVE" ]; then
    dest="${ARCHIVE%/}/$TAG"
    log "archiving to $dest"
    rclone copy "$STAGE" "$dest"
    rclone check --one-way "$STAGE" "$dest" || die "the archive copy at $dest does not match — run again"
    log "archive matches"
else
    log "no archive remote — skipped (--archive or MODERNOS_ISO_ARCHIVE)"
fi
log "done: $WEB/releases/latest/download/$ISO_ASSET"
