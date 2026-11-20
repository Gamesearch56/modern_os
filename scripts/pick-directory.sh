#!/usr/bin/env bash
# Print the real path of a directory the file manager already chose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

chosen="$(expand_home "${1:-}")"
if [ -z "$chosen" ] || [ ! -d "$chosen" ]; then
    echo "pick-directory: not a directory" >&2
    exit 3
fi

printf '%s\n' "$(realpath "$chosen")"
