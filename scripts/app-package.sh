#!/usr/bin/env bash
# Which pacman package owns an application, and may it be uninstalled.
# Read-only; the removal itself is pkg-mutate.sh behind the Store dialog.
#
# Usage: app-package.sh <desktop-id>
# Prints one JSON line: {"pkg": "...", "removable": true|false,
#   "why": "" | "notPackaged" | "system"}
# notPackaged: no package owns the desktop file (ModernOS apps, web apps,
# Flatpaks, files the user made). system: a protected or core package,
# which pkg-mutate.sh refuses to remove.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"
PACMAN="${MODERN_PACMAN:-/usr/bin/pacman}"

answer() {
    jq -cn --arg pkg "$1" --argjson removable "$2" --arg why "$3" \
        '{pkg: $pkg, removable: $removable, why: $why}'
}

id="${1:-}"
id="${id%.desktop}"
if ! [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,200}$ ]]; then
    answer "" false notPackaged
    exit 0
fi

# A user copy can shadow the packaged file under the same id, so every
# directory is asked, not only the first match.
dirs=("${XDG_DATA_HOME:-$HOME/.local/share}")
IFS=: read -r -a more <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
dirs+=("${more[@]}")

pkg=""
for d in "${dirs[@]}"; do
    file="$d/applications/$id.desktop"
    [ -f "$file" ] || continue
    owner="$(LC_ALL=C "$PACMAN" -Qqo -- "$(readlink -f -- "$file")" 2>/dev/null | head -n 1 || true)"
    if [ -n "$owner" ] && valid_pkg_name "$owner"; then
        pkg="$owner"
        break
    fi
done

if [ -z "$pkg" ]; then
    answer "" false notPackaged
    exit 0
fi
if protected_pkg "$pkg" \
    || "$ROOT/pkg-manifest-names.sh" --core | jq -e --arg n "$pkg" 'index($n) != null' >/dev/null 2>&1; then
    answer "$pkg" false system
    exit 0
fi
answer "$pkg" true ""
