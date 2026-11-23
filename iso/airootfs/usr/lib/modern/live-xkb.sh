#!/usr/bin/env bash
# The installer's keyboard. setxkbmap alone is ignored the first time
# on this Xwayland, so the map is compiled into the server as well.
# The next key then uses the layout that was just chosen.
set -eu
layout="${1:-us}"
variant="${2:-}"
export DISPLAY="${DISPLAY:-:0}"
args=(-layout "$layout" -option "")
if [ -n "$variant" ]; then
    args+=(-variant "$variant")
fi
setxkbmap "${args[@]}" || true
setxkbmap -print | xkbcomp - "$DISPLAY" >/dev/null 2>&1 || true
