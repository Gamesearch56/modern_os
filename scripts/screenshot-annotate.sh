#!/usr/bin/env bash
# Annotate via the same screenshot.sh path so directory/config stay one place.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/screenshot.sh" "${1:-region}" "${2:-}"
