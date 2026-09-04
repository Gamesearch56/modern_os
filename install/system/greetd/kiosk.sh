#!/usr/bin/env bash
# greetd's greeter command. Quickshell.Services.Greetd connects only when
# GREETD_SOCK is set; start-hyprland / Hyprland exec of qs otherwise drops
# it and createSession fails with "Connection refused (os error: 111)".
set -euo pipefail

sock="${GREETD_SOCK:-}"
[ -n "$sock" ] || {
    printf 'greetd-kiosk: GREETD_SOCK is unset — greetd did not start this process\n' >&2
    exit 1
}

runtime="${XDG_RUNTIME_DIR:-}"
if [ -n "$runtime" ] && [ -d "$runtime" ]; then
    printf '%s\n' "$sock" >"$runtime/greetd.sockpath"
    chmod 0600 "$runtime/greetd.sockpath"
fi

export GREETD_SOCK="$sock"
exec /usr/bin/env GREETD_SOCK="$sock" /usr/bin/start-hyprland -- --config /etc/greetd/hyprland.lua
