#!/usr/bin/env bash
# Home, XDG folders, recent files, network mounts, and disk mounting.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/files_places.py" "$@"
