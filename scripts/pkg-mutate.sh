#!/usr/bin/env bash
# Install or remove one official-repo package. pkexec + argv only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"

action="${1:-}"
name="${2:-}"
if [ "$action" != "install" ] && [ "$action" != "remove" ]; then
    printf 'usage: pkg-mutate.sh install|remove <name>\n' >&2
    exit 2
fi
if ! valid_pkg_name "$name"; then
    printf 'invalid package name\n' >&2
    exit 2
fi

PACMAN="${PACMAN:-/usr/bin/pacman}"
export LC_ALL=C
if [ "$action" = "install" ]; then
    exec pkexec "$PACMAN" -S --noconfirm --needed -- "$name"
fi
exec pkexec "$PACMAN" -Rns --noconfirm -- "$name"
