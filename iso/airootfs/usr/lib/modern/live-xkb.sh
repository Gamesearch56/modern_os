#!/usr/bin/env bash
# Cage decides which character a key produces. The helper loaded into
# cage reads this file on its next frame. setxkbmap still runs for
# anything that reads the X server map; cage itself does not.
set -eu
layout="${1:-us}"
variant="${2:-}"
case "$layout" in
    *[!A-Za-z0-9_-]*) layout=us ;;
esac
case "$variant" in
    *[!A-Za-z0-9_-]*) variant="" ;;
esac
mkdir -p /run/modern
chmod 755 /run/modern
# The installer writes this as root. Cage runs as the live user and
# has to be able to read it, so the file stays world-readable.
printf '%s\n%s\n' "$layout" "$variant" >/run/modern/xkb-layout
chmod 644 /run/modern/xkb-layout
export DISPLAY="${DISPLAY:-:0}"
if [ -n "$variant" ]; then
    setxkbmap -layout "$layout" -variant "$variant" || true
else
    setxkbmap -layout "$layout" || true
fi
