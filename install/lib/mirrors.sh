#!/usr/bin/env bash
# Two-week pacman mirror refresh. Applied by install.sh on a login home
# (and by the root plan when Settings cannot sudo). Not an initramfs change.
# Source, never execute directly.
set -euo pipefail

mirrors_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo -- "$@"
    fi
}

# Copy the refresh script and enable modern-mirrors.timer.
# MIRRORS_SKIP_REFRESH=1 only arms the timer (the caller just refreshed).
mirrors_apply() {
    local repo="${REPO_ROOT:-}"
    [ -n "$repo" ] || {
        printf 'mirrors: REPO_ROOT is not set\n' >&2
        return 1
    }
    if [ "${DRY_RUN:-0}" = 1 ]; then
        printf 'mirrors: would enable modern-mirrors.timer\n'
        return 0
    fi
    mirrors_as_root install -d -m 0755 /usr/local/lib/modern /var/lib/modern
    mirrors_as_root install -m 0755 \
        "$repo/scripts/mirrors-refresh.sh" /usr/local/lib/modern/mirrors-refresh.sh
    mirrors_as_root install -m 0755 \
        "$repo/scripts/mirror-country.sh" /usr/local/lib/modern/mirror-country.sh
    mirrors_as_root install -m 0644 \
        "$repo/install/system/mirrors/modern-mirrors.service" \
        /etc/systemd/system/modern-mirrors.service
    mirrors_as_root install -m 0644 \
        "$repo/install/system/mirrors/modern-mirrors.timer" \
        /etc/systemd/system/modern-mirrors.timer
    mirrors_as_root systemctl daemon-reload
    mirrors_as_root systemctl enable modern-mirrors.timer
    mirrors_as_root systemctl start modern-mirrors.timer
    if [ "${MIRRORS_SKIP_REFRESH:-0}" = 1 ]; then
        return 0
    fi
    mirrors_as_root /usr/local/lib/modern/mirrors-refresh.sh --auto
}
