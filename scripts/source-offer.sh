#!/usr/bin/env bash
# Written offer for the source of one ModernOS image.
#
# The image is a mix of ModernOS and Arch Linux packages. Giving someone
# the image means offering them the matching source for three years.
# ModernOS itself is the git tag. Every other package is the Arch source
# package of that exact version on archive.archlinux.org. If that file
# is gone, the offer below is how to ask for a copy.
set -euo pipefail

PACKAGES=""
ROOTFS=""
TAG=""
DAY=""
OUT=""

die() { printf 'source-offer: ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --packages) PACKAGES="${2:-}"; shift ;;
        --root) ROOTFS="${2:-}"; shift ;;
        --tag) TAG="${2:-}"; shift ;;
        --date) DAY="${2:-}"; shift ;;
        --out) OUT="${2:-}"; shift ;;
        -h|--help)
            echo "usage: source-offer.sh --tag vX.Y.Z --out DIR (--packages FILE | --root DIR) [--date YYYY-MM-DD]"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "need a vX.Y.Z tag"
[ -n "$OUT" ] || die "need --out"
if [ -z "$DAY" ]; then
    DAY="$(date -u +%F)"
fi
[[ "$DAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "date must be YYYY-MM-DD"

list="$(mktemp)"
trap 'rm -f "$list"' EXIT
if [ -n "$PACKAGES" ]; then
    [ -f "$PACKAGES" ] || die "no package list at $PACKAGES"
    cp "$PACKAGES" "$list"
elif [ -n "$ROOTFS" ]; then
    [ -d "$ROOTFS/var/lib/pacman/local" ] || die "no pacman database under $ROOTFS"
    pacman --dbpath "$ROOTFS/var/lib/pacman" -Q >"$list"
else
    die "need --packages or --root"
fi

mkdir -p "$OUT"
pkgfile="$OUT/${TAG}-PACKAGES.txt"
offer="$OUT/${TAG}-SOURCE-OFFER.txt"
sort -u "$list" | awk 'NF { print $1, $2 }' >"$pkgfile"

cat >"$offer" <<EOF
ModernOS source offer
Release: ${TAG}
Date: ${DAY}

This file accompanies the ModernOS image for ${TAG}. For three years
from ${DAY}, anyone who has that image can get the source that matches
the programs on it, at no charge.

ModernOS itself (the desktop, installer and scripts) is the git tag
${TAG} of https://github.com/Gamesearch56/modern_os

Every other package is listed in ${TAG}-PACKAGES.txt as name and
version. Its source is the Arch Linux source package of that exact
version:

  https://archive.archlinux.org/packages/<first letter>/<name>/<name>-<version>.src.tar.gz

Example: bash 5.2.037-1 is
  https://archive.archlinux.org/packages/b/bash/bash-5.2.037-1.src.tar.gz

If a file is missing from that archive, ask at
https://github.com/Gamesearch56/modern_os/issues
and a copy of that source package will be provided. This offer lasts
until ${DAY} plus three years.
EOF

printf 'source-offer: wrote %s and %s\n' "$offer" "$pkgfile"
