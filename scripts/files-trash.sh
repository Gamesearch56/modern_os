#!/usr/bin/env bash
# Move files into this user's XDG trash, list them, restore, or empty it.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/files_trash.py" "$@"
