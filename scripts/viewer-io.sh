#!/usr/bin/env bash
# File access for the ModernOS Imageviewer (scripts/lib/viewer_io.py).
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/viewer_io.py" "$@"
