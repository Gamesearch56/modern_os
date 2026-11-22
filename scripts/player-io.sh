#!/usr/bin/env bash
# The Mediaplayer's only file access: scripts/lib/player_io.py. One JSON line out.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/player_io.py" "$@"
