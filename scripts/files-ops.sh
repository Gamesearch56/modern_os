#!/usr/bin/env bash
# List, create, rename, copy, move, and permission changes.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/files_ops.py" "$@"
