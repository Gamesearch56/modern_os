#!/usr/bin/env bash
# Open (or print) the changelog for one pending update. Desktop
# releases are this GitHub repo; official packages use Arch's packaging
# compare between the two versions checkupdates reported.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/deploy-key.sh
source "$SCRIPT_DIR/lib/deploy-key.sh"

die() { printf 'update-changelog: ERROR: %s\n' "$*" >&2; exit 1; }

PRINT=0
if [ "${1:-}" = "--print" ]; then
    PRINT=1
    shift
fi

KIND="${1:-}"
NAME="${2:-}"
FROM="${3:-}"
TO="${4:-}"

[ -n "$KIND" ] && [ -n "$NAME" ] || \
    die "usage: update-changelog.sh [--print] desktop|pkg <name> <from> <to>"

case "$KIND" in
    desktop|pkg) ;;
    *) die "kind must be desktop or pkg" ;;
esac
if [ "$KIND" != "desktop" ] && [ -z "$TO" ]; then
    die "usage: update-changelog.sh [--print] desktop|pkg <name> <from> <to>"
fi

# Package names and versions only. A slash or query would become another
# URL path.
ok_seg() {
    [[ "$1" =~ ^[A-Za-z0-9@._+:~-]+$ ]]
}

ok_seg "$NAME" || die "invalid name"
[ -z "$FROM" ] || ok_seg "$FROM" || die "invalid from"
[ -z "$TO" ] || ok_seg "$TO" || die "invalid to"

url=""
if [ "$KIND" = "desktop" ]; then
    web="$(github_web_url)"
    # HEAD / no from-tag: this checkout is not a release, so the list
    # is the page that still makes sense.
    if [ -n "$FROM" ] && [ "$FROM" != "HEAD" ] && [ -n "$TO" ]; then
        url="${web}/compare/${FROM}...${TO}"
    else
        url="${web}/releases"
    fi
elif [ -n "$FROM" ]; then
    url="https://gitlab.archlinux.org/archlinux/packaging/packages/${NAME}/-/compare/${FROM}...${TO}"
else
    url="https://gitlab.archlinux.org/archlinux/packaging/packages/${NAME}/-/commits/${TO}"
fi

if [ "$PRINT" -eq 1 ]; then
    printf '%s\n' "$url"
    exit 0
fi

exec /usr/bin/xdg-open "$url"
