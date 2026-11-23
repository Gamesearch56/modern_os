#!/usr/bin/env bash
# Start a program and show the watch cursor while it maps. The cursor
# helper returns immediately; exec keeps this process as the app.
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: launch-exec.sh COMMAND [args...]" >&2
    exit 2
fi

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -x "$dir/cursor-busy.sh" ]]; then
    "$dir/cursor-busy.sh" start || true
fi
exec "$@"
