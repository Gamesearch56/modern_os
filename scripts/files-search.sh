#!/usr/bin/env bash
# Name search uses find. Content search uses grep. Both take an argv list.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/files_search.py" "$@"
