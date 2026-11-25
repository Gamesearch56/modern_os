#!/usr/bin/env bash
# User session after the greeter. Hyprland's startup banner goes to the
# seat terminal; a laptop draws that terminal until the first frame.
set -euo pipefail

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
log="$log_dir/hyprland.log"
mkdir -p "$log_dir"
# One file per login would be lost on crash; one header per login keeps
# the session that failed findable in the bug report. Opening a log that
# does not exist yet prints that error on the seat, between login and
# the desktop.
if [ -f "$log" ] && [ "$(wc -c <"$log")" -gt 2097152 ]; then
    mv -f "$log" "$log.1"
fi
printf '\n== desktop session %s (uid %s, session %s)\n' "$(date -Is)" "$(id -u)" "${XDG_SESSION_ID:-?}" >>"$log"
# The greeter turns the CRTC off as it exits. Cover that blank before
# this compositor starts, and do not stay DRM master.
if [ "${MODERN_SEAT_COVER:-1}" != 0 ] && [ -f /usr/lib/modern/seat-cover.py ]; then
    python3 /usr/lib/modern/seat-cover.py hold >>"$log" 2>&1 || true
fi
# The first desktop frame is a modeset even when the greeter left a
# CRTC scanning. The helper makes that frame a page flip. Screen
# blanking still modesets; only the greeter sets MODERN_SEAT_KEEP_CRTC.
if [ -f /usr/lib/modern/seat-nomodeset.so ]; then
    export LD_PRELOAD="/usr/lib/modern/seat-nomodeset.so${LD_PRELOAD:+:$LD_PRELOAD}"
fi
unset MODERN_SEAT_KEEP_CRTC
exec "${MODERN_START_HYPRLAND:-/usr/bin/start-hyprland}" --no-nixgl >>"$log" 2>&1
