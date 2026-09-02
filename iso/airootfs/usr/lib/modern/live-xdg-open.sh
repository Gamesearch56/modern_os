#!/usr/bin/env bash
# Live ISO: open URLs on the liveuser compositor (same Wayland socket).
set -euo pipefail

exec /usr/bin/xdg-open "$@"
