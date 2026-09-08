#!/usr/bin/env bash
# Hold session idle inhibit until this process is killed.
# hypridle honors org.freedesktop.ScreenSaver (ignore_dbus_inhibit =
# false). logind systemd-inhibit --what=idle does not pause its timers.
set -euo pipefail

cookie=""

cleanup() {
    if [[ "${cookie}" =~ ^[0-9]+$ ]]; then
        busctl --user call org.freedesktop.ScreenSaver \
            /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver UnInhibit \
            u "$cookie" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM HUP

out="$(busctl --user call org.freedesktop.ScreenSaver \
    /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver Inhibit \
    ss modern "Idle inhibit" 2>/dev/null || true)"
cookie="$(printf '%s' "$out" | awk '{ for (i = 1; i <= NF; i++) if ($i == "u") { print $(i + 1); exit } }')"

exec sleep infinity
