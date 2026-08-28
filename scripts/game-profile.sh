#!/usr/bin/env bash
# Prints a Steam launch-options string from the wrappers the user asked
# for. Paste the line into Steam → Game → Properties → Launch Options.
# AMD / RADV / HDR environment presets are documented as comments in
# docs/GAMING.md — they stay out of this string so a title that hates
# RADV_PERFTEST is not silently broken.
#
# Usage: game-profile.sh [--gamemode] [--gamescope] [--mangohud]
set -euo pipefail

usage() {
    grep '^#' "$0" | cut -c3- | head -n 10
}

GAMEMODE=0
GAMESCOPE=0
MANGOHUD=0

while [ $# -gt 0 ]; do
    case "$1" in
        --gamemode) GAMEMODE=1 ;;
        --gamescope) GAMESCOPE=1 ;;
        --mangohud) MANGOHUD=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'game-profile: unknown flag %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

parts=()
[ "$GAMEMODE" -eq 1 ] && parts+=(gamemoderun)
# gamescope must wrap the rest so MangoHud/the game run *inside* it.
if [ "$GAMESCOPE" -eq 1 ]; then
    parts+=(gamescope --)
fi
[ "$MANGOHUD" -eq 1 ] && parts+=(mangohud)
parts+=('%command%')

printf '%s\n' "${parts[*]}"
