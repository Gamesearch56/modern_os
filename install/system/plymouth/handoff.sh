#!/usr/bin/env bash
# Plymouth is still showing. Quit only after the login compositor has
# the display, so the console — and the firmware logo in it — never
# comes back between the splash and the login screen.
set -euo pipefail

if [ -r /usr/lib/modern/display-handoff.sh ]; then
    # shellcheck disable=SC1091
    source /usr/lib/modern/display-handoff.sh
    display_handoff_prepare
fi

deadline=$((SECONDS + 12))
while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -n "$(find /run/user -name hyprland.lock -print -quit 2>/dev/null || true)" ]; then
        # The lock exists once the compositor has opened the device.
        # One beat lets its first frame replace the splash.
        sleep 0.5
        plymouth quit --retain-splash || true
        exit 0
    fi
    sleep 0.1
done
plymouth quit --retain-splash || true
