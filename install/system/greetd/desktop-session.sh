#!/usr/bin/env bash
# User session after the greeter. Hyprland's startup banner goes to the
# seat terminal; a laptop draws that terminal until the first frame.
set -euo pipefail

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
mkdir -p "$log_dir"
exec /usr/bin/start-hyprland --no-nixgl >>"$log_dir/hyprland.log" 2>&1
