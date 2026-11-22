#!/usr/bin/env bash
# Greetd + Quickshell greeter. Sourced by install.sh (sudo) and by
# provision-iso.sh (root). Idempotent.
# shellcheck disable=SC2034
set -euo pipefail

greetd_log() {
    if command -v log_info >/dev/null 2>&1; then
        log_info "greetd: $*"
    else
        printf 'greetd: %s\n' "$*"
    fi
}

greetd_as_root() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Login homes only: CI and --target /tmp runs must not enable greetd on
# the machine running them.
greetd_target_is_live_user() {
    local home="$1" resolved user
    [ -n "$home" ] || return 1
    resolved="$(readlink -f "$home" 2>/dev/null || true)"
    [ -n "$resolved" ] || return 1
    case "$resolved" in
        /tmp|/tmp/*|/var/tmp|/var/tmp/*|/dev/*)
            return 1
            ;;
    esac
    user="$(getent passwd | awk -F: -v h="$resolved" '$6==h { print $1; exit }')"
    [ -n "$user" ]
}

greetd_user_for_home() {
    local home="$1" resolved
    resolved="$(readlink -f "$home" 2>/dev/null || true)"
    getent passwd | awk -F: -v h="$resolved" '$6==h { print $1; exit }'
}

# One unit per call: `systemctl enable a b c` aborts the whole list on the
# first missing unit, so one absent package would take the install down.
# --root=/ reads this filesystem. During install, /run is the live
# session, where NetworkManager is already enabled. A plain is-enabled
# then skips the installed copy, systemd-networkd has been removed, and
# the new system boots with no address.
enable_unit() {
    local unit="$1" need="$2"
    if [ "${DRY_RUN:-0}" = "1" ]; then
        greetd_log "would enable $unit ($need)"
        return 0
    fi
    if systemctl --root=/ is-enabled "$unit" >/dev/null 2>&1; then
        greetd_log "already enabled $unit"
        return 0
    fi
    if greetd_as_root systemctl --root=/ enable "$unit"; then
        greetd_log "enabled $unit"
        return 0
    fi
    [ "$need" = required ] && {
        printf 'greetd: ERROR: cannot enable %s — need sudo, and the package installed?\n' "$unit" >&2
        exit 1
    }
    greetd_log "skipping $unit (not installed)"
}

# Apply greetd, greeter home, session tmpfiles, default-user.
# Usage: greetd_apply <username>
greetd_apply() {
    local username="${1:-}"
    local repo="${REPO_ROOT:-${PROVISION_ROOT:-}}"
    local user_home greeter_home wp dropin
    [ -n "$username" ] || {
        printf 'greetd: ERROR: greetd_apply <username>\n' >&2
        exit 1
    }
    [ -n "$repo" ] || {
        printf 'greetd: ERROR: REPO_ROOT or PROVISION_ROOT must be set\n' >&2
        exit 1
    }
    id "$username" >/dev/null 2>&1 || {
        printf 'greetd: ERROR: user %s does not exist\n' "$username" >&2
        exit 1
    }
    user_home="$(getent passwd "$username" | cut -d: -f6)"

    greetd_log "enabling NetworkManager bluetooth greetd systemd-timesyncd"
    enable_unit NetworkManager.service required
    enable_unit greetd.service required
    enable_unit bluetooth.service optional
    enable_unit systemd-timesyncd.service optional
    greetd_as_root systemctl set-default graphical.target

    greetd_as_root install -d -m 0755 /etc/greetd
    greetd_as_root install -m 0644 "$repo/install/system/greetd/config.toml" /etc/greetd/config.toml
    if [ -f "$repo/install/system/greetd/greetd.pam" ]; then
        greetd_as_root install -m 0644 "$repo/install/system/greetd/greetd.pam" /etc/pam.d/greetd
    fi
    if [ -f "$repo/install/system/greetd/keyring-login.sh" ]; then
        greetd_as_root install -d -m 0755 /usr/lib/modern
        greetd_as_root install -m 0755 \
            "$repo/install/system/greetd/keyring-login.sh" \
            /usr/lib/modern/keyring-login.sh
        greetd_as_root install -m 0755 \
            "$repo/install/system/greetd/keyring-match.py" \
            /usr/lib/modern/keyring-match.py
    fi
    greetd_as_root install -m 0644 "$repo/install/system/greetd/hyprland.lua" /etc/greetd/hyprland.lua
    greetd_as_root install -m 0755 "$repo/install/system/greetd/kiosk.sh" /etc/greetd/kiosk.sh
    greetd_as_root install -d -m 0755 /usr/lib/modern
    greetd_as_root install -m 0755 \
        "$repo/install/system/greetd/desktop-session.sh" \
        /usr/lib/modern/desktop-session.sh
    greetd_as_root install -m 0755 "$repo/install/system/greetd/list-users.py" /etc/greetd/list-users.py
    if [ -f "$repo/stow/hypr/.config/hypr/lib/json.lua" ]; then
        greetd_as_root install -m 0644 "$repo/stow/hypr/.config/hypr/lib/json.lua" /etc/greetd/json.lua
    fi
    if [ -f "$repo/install/system/greetd/50-modern-greeter.rules" ]; then
        greetd_as_root install -D -m 0644 \
            "$repo/install/system/greetd/50-modern-greeter.rules" \
            /etc/polkit-1/rules.d/50-modern-greeter.rules
    fi

    if ! getent group modern >/dev/null 2>&1; then
        greetd_as_root groupadd --system modern
    fi
    greeter_home=/var/lib/greeter
    if ! id greeter >/dev/null 2>&1; then
        greetd_as_root useradd --system --create-home --home-dir "$greeter_home" \
            --shell /usr/bin/nologin --gid modern -G video,seat greeter || true
    else
        case "$(getent passwd greeter | cut -d: -f6)" in
            "$greeter_home") ;;
            *) greetd_as_root usermod --home "$greeter_home" greeter || true ;;
        esac
        for g in modern video seat; do
            if getent group "$g" >/dev/null 2>&1; then
                greetd_as_root gpasswd -a greeter "$g" >/dev/null 2>&1 || true
            fi
        done
    fi
    greetd_as_root install -d -m 0755 "$greeter_home"
    greetd_as_root chown greeter:modern "$greeter_home" || true
    greetd_as_root gpasswd -a "$username" modern >/dev/null 2>&1 || true
    if [ -f "$repo/install/system/tmpfiles.d/modern-session.conf" ]; then
        greetd_as_root install -m 0644 "$repo/install/system/tmpfiles.d/modern-session.conf" \
            /etc/tmpfiles.d/modern-session.conf
        greetd_as_root systemd-tmpfiles --create /etc/tmpfiles.d/modern-session.conf || true
    fi
    # Session dir before wallpaper-sync: magick cannot write 2775 root:modern
    # until the tree exists, and install.sh is not root so it cannot use it
    # until the login user is in `modern` (gpasswd above; this copy runs as root).
    greetd_as_root install -d -m 2775 /var/lib/modern/session
    greetd_as_root chown root:modern /var/lib/modern/session || true

    # getent exits 2 when the account is missing; pipefail would abort
    # dry-run on CI (no greeter user) before the next log line.
    greeter_home="$(getent passwd greeter 2>/dev/null | cut -d: -f6 || true)"
    case "$greeter_home" in
        ""|/)
            if [ "${DRY_RUN:-0}" = "1" ]; then
                greetd_log "would create greeter home at /var/lib/greeter"
                greeter_home=/var/lib/greeter
            else
                printf 'greetd: ERROR: greeter still has %s as its home — qs -c greeter cannot start\n' "$greeter_home" >&2
                exit 1
            fi
            ;;
    esac
    if [ -d "$repo/stow/greeter" ]; then
        greetd_as_root install -d -m 0755 "$greeter_home/.config/quickshell"
        greetd_as_root rm -rf "$greeter_home/.config/quickshell/greeter"
        greetd_as_root cp -a "$repo/stow/greeter/.config/quickshell/greeter" \
            "$greeter_home/.config/quickshell/greeter"
        greetd_as_root chown -R greeter:modern "$greeter_home/.config" || true
    fi

    wp="${user_home}/.config/modern/wallpapers/default.jpg"
    if [ -f "$repo/scripts/wallpaper-sync.sh" ] && [ -f "$wp" ]; then
        # magick follows HOME. Without a private cache it creates
        # ~/.cache as root, and kitty then cannot start.
        greetd_as_root install -d -m 0700 /var/tmp/modern-root-cache
        greetd_as_root env \
            HOME="$user_home" \
            USER="$username" \
            XDG_CONFIG_HOME="${user_home}/.config" \
            XDG_STATE_HOME="${user_home}/.local/state" \
            XDG_CACHE_HOME=/var/tmp/modern-root-cache \
            MAGICK_TMPDIR=/var/tmp/modern-root-cache \
            bash "$repo/scripts/wallpaper-sync.sh" "$wp" || true
        cache="${user_home}/.cache"
        if [ -d "$cache" ] && [ ! -L "$cache" ]; then
            grp="$(id -gn "$username" 2>/dev/null || printf '%s' "$username")"
            greetd_as_root chown -hR "$username:$grp" "$cache" || true
        fi
        # a+rX makes the greeter able to read. It does not add group write,
        # and the root sync above creates wallpapers as 2755.
        greetd_as_root chmod -R a+rX /var/lib/modern/session 2>/dev/null || true
        greetd_as_root chmod 2775 /var/lib/modern/session || true
        for sub in wallpapers faces; do
            if [ -d "/var/lib/modern/session/$sub" ]; then
                greetd_as_root chown "root:modern" "/var/lib/modern/session/$sub" || true
                greetd_as_root chmod 2775 "/var/lib/modern/session/$sub" || true
            fi
        done
    fi
    if [ "${DRY_RUN:-0}" = "1" ]; then
        greetd_log "would write /var/lib/modern/session/default-user -> $username"
    else
        printf '%s\n' "$username" | greetd_as_root tee /var/lib/modern/session/default-user >/dev/null
        greetd_as_root chown root:modern /var/lib/modern/session/default-user || true
        greetd_as_root chmod 0664 /var/lib/modern/session/default-user
    fi

    for dropin in \
        /etc/systemd/system/getty@tty1.service.d/99-modern-autologin.conf \
        /etc/systemd/system/getty@tty1.service.d/override.conf \
        /etc/systemd/system/getty@tty1.service.d/autologin.conf
    do
        if [ -e "$dropin" ]; then
            greetd_as_root rm -f "$dropin"
            greetd_log "removed $dropin"
        fi
    done
    greetd_as_root systemctl daemon-reload || true
    greetd_log "login screen applied for $username"
}
