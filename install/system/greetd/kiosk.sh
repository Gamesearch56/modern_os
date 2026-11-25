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

# qs Process stdout is easy to miss before the first window; write the
# select list here so SessionUsers can FileView it.
write_users() {
    local dest="$1" tmp
    [ -n "$dest" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0
    [ -f /etc/greetd/list-users.py ] || return 0
    tmp="${dest}.tmp"
    if python3 /etc/greetd/list-users.py >"$tmp"; then
        chmod a+r "$tmp" || true
        mv -f "$tmp" "$dest"
    else
        rm -f "$tmp"
    fi
}

if [ -n "$runtime" ] && [ -d "$runtime" ]; then
    write_users "$runtime/modern-users.json"
fi
write_users /var/lib/modern/session/users.json || true

# nologin greeter accounts often have no PATH; Hyprland then warns that
# hyprland-guiutils is missing even when hyprland-dialog is in /usr/bin.
export PATH="/usr/bin:/bin:${PATH:-/usr/bin}"

# greetd hands the greeter no LANG, so Qt starts in the C locale and warns
# that it is not UTF-8.
if [ -z "${LANG:-}" ]; then
    lang=""
    [ -r /etc/locale.conf ] && lang="$(sed -n 's/^LANG=//p' /etc/locale.conf | tr -d '"' | head -n1)"
    export LANG="${lang:-C.UTF-8}"
fi

# A coredump while greetd reaps this compositor leaves a black seat.
ulimit -c 0

export GREETD_SOCK="$sock"
# Arch Hyprland is not a Nix install; --no-nixgl skips the nixGL probe.
# The banner belongs in a log. On a laptop it would otherwise be the
# picture between the splash and the login screen.
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
log="$log_dir/hyprland.log"
mkdir -p "$log_dir"
# Same as the desktop session: the first login has no log file yet.
if [ -f "$log" ] && [ "$(wc -c <"$log")" -gt 2097152 ]; then
    mv -f "$log" "$log.1"
fi
printf '\n== login screen %s\n' "$(date -Is)" >>"$log"
# The panel shows its firmware logo while no CRTC is scanning. Paint one
# frame and drop master before Hyprland opens the device.
if [ "${MODERN_SEAT_COVER:-1}" != 0 ] && [ -f /usr/lib/modern/seat-cover.py ]; then
    python3 /usr/lib/modern/seat-cover.py hold >>"$log" 2>&1 || true
fi
# The greeter's exit modesets the panel off. The desktop then modesets
# from a dark link, and this laptop draws its firmware picture for that
# retrain. The helper turns that off-commit into a no-op.
if [ -f /usr/lib/modern/seat-nomodeset.so ]; then
    export LD_PRELOAD="/usr/lib/modern/seat-nomodeset.so${LD_PRELOAD:+:$LD_PRELOAD}"
    export MODERN_SEAT_KEEP_CRTC=1
fi
exec /usr/bin/env GREETD_SOCK="$sock" MODERN_SEAT_KEEP_CRTC="${MODERN_SEAT_KEEP_CRTC:-}" LD_PRELOAD="${LD_PRELOAD:-}" "${MODERN_START_HYPRLAND:-/usr/bin/start-hyprland}" --no-nixgl -- --config /etc/greetd/hyprland.lua >>"$log" 2>&1
