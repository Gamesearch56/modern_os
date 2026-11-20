#!/usr/bin/env bash
# Print `path<TAB>thumbnail` for each image, video, or PDF that has a preview.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -u "$dir/lib/files_thumbs.py" "$@"
