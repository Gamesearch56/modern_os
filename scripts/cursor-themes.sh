#!/usr/bin/env bash
# Print installed cursor theme names (directories that contain cursors/).
set -euo pipefail

data="${XDG_DATA_HOME:-$HOME/.local/share}"
{
    for dir in /usr/share/icons /usr/local/share/icons "$data/icons" "$HOME/.icons"; do
        [ -d "$dir" ] || continue
        for theme in "$dir"/*; do
            [ -d "$theme/cursors" ] || continue
            basename "$theme"
        done
    done
} | sort -u
