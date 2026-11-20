#!/usr/bin/env bash
# One more file manager window. A separate process so it does not move
# the window that is already open.
set -euo pipefail

export MODERN_FILE_WINDOW=1
export MODERN_FILE_PATH="${1:-}"
config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/modern/files-window.qml"
exec qs -p "$config"
