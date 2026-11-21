#!/usr/bin/env bash
# Load, save, trash, and claim files for the ModernOS Texteditor.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$dir/lib/editor_io.py" "$@"
