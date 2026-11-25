#!/usr/bin/env bash
# Create a zip of selected files, or extract one beside itself.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/files_zip.py" "$@"
