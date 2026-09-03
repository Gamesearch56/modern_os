#!/usr/bin/env bash
# GATED — Calamares late / ISO chroot only. Enables greetd, NetworkManager,
# bluetooth. Refuses when MODERN_PROTECT_HOME is set and exists.
# See docs/ISOLATION.md.
#
# Usage: MODERN_ISO_PROVISION=1 provision-iso.sh <username>
set -euo pipefail

PROVISION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROVISION_ROOT

die() { printf 'provision-iso: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'provision-iso: %s\n' "$*"; }

USERNAME="${1:-}"
[ -n "$USERNAME" ] || die "usage: $0 <username>"
id "$USERNAME" >/dev/null 2>&1 || die "user $USERNAME does not exist"

if [ -n "${MODERN_PROTECT_HOME:-}" ] && [ -d "${MODERN_PROTECT_HOME%/}" ]; then
    die "refusing to run while MODERN_PROTECT_HOME is set and exists"
fi
if [ "${MODERN_ISO_PROVISION:-}" != "1" ]; then
    die "refusing to run without MODERN_ISO_PROVISION=1 (Calamares late only)"
fi
if [ "$(id -u)" -ne 0 ]; then
    die "run as root in the install target"
fi

# shellcheck source=nvidia/apply.sh
source "$PROVISION_ROOT/install/system/nvidia/apply.sh"

# One unit per call: `systemctl enable a b c` aborts the whole list on the
# first missing unit, so one absent package used to take the install down.
enable_unit() {
    local unit="$1" need="$2"
    if systemctl enable "$unit" >/dev/null 2>&1; then
        log "enabled $unit"
        return 0
    fi
    [ "$need" = required ] && die "cannot enable $unit — is its package installed?"
    log "skipping $unit (not installed)"
}

log "enabling NetworkManager bluetooth greetd systemd-timesyncd"
enable_unit NetworkManager.service required
enable_unit greetd.service required
enable_unit bluetooth.service optional
enable_unit systemd-timesyncd.service optional
systemctl set-default graphical.target

install -d -m 0755 /etc/greetd
install -m 0644 "$PROVISION_ROOT/install/system/greetd/config.toml" /etc/greetd/config.toml
install -m 0644 "$PROVISION_ROOT/install/system/greetd/hyprland.lua" /etc/greetd/hyprland.lua

if ! getent group modern >/dev/null 2>&1; then
    groupadd --system modern
fi
# greetd's own sysusers.d entry (`u greeter - "greetd greeter user" -`)
# leaves the home field unset, so systemd-sysusers already created greeter
# with / as its home when the package landed and this useradd never runs.
# A greeter whose $HOME is / cannot create /.cache or /.local/state, and
# anything of ours that resolves $HOME writes to //.config.
GREETER_HOME=/var/lib/greeter
if ! id greeter >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "$GREETER_HOME" \
        --shell /usr/bin/nologin --gid modern -G video,seat greeter || true
else
    case "$(getent passwd greeter | cut -d: -f6)" in
        "$GREETER_HOME") ;;
        # No --move-home: the old home is / and usermod would move the
        # whole root filesystem into /var/lib/greeter.
        *) usermod --home "$GREETER_HOME" greeter || true ;;
    esac
    for g in modern video seat; do
        if getent group "$g" >/dev/null 2>&1; then
            gpasswd -a greeter "$g" >/dev/null 2>&1 || true
        fi
    done
fi
install -d -m 0755 "$GREETER_HOME"
chown greeter:modern "$GREETER_HOME" || true
if [ -f "$PROVISION_ROOT/install/system/tmpfiles.d/modern-session.conf" ]; then
    install -m 0644 "$PROVISION_ROOT/install/system/tmpfiles.d/modern-session.conf" \
        /etc/tmpfiles.d/modern-session.conf
    systemd-tmpfiles --create /etc/tmpfiles.d/modern-session.conf || true
fi

# passwd, not the variable above: this is where the greeter will actually
# look, and a copy into /var/lib/greeter is useless if usermod did not take.
GREETER_HOME="$(getent passwd greeter | cut -d: -f6)"
case "$GREETER_HOME" in
    ""|/) die "greeter still has '$GREETER_HOME' as its home — qs -c greeter cannot start" ;;
esac
if [ -d "$PROVISION_ROOT/stow/greeter" ]; then
    install -d -m 0755 "$GREETER_HOME/.config/quickshell"
    rm -rf "$GREETER_HOME/.config/quickshell/greeter"
    cp -a "$PROVISION_ROOT/stow/greeter/.config/quickshell/greeter" \
        "$GREETER_HOME/.config/quickshell/greeter"
    chown -R greeter:modern "$GREETER_HOME/.config" || true
fi

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

# Calamares' keyboard job writes the chosen layout to /etc/vconsole.conf and
# the X11 snippet, which covers the TTY and Xwayland clients. Neither is read
# by Hyprland (modules/input.lua takes kb_layout from config.json) or by
# greetd's own Hyprland instance, so a German install used to boot to a us
# login prompt and a us desktop.
XORG_KB="${MODERN_XORG_KB:-/etc/X11/xorg.conf.d/00-keyboard.conf}"
GREETD_LUA="${MODERN_GREETD_LUA:-/etc/greetd/hyprland.lua}"

xkb_option() {
    sed -nE "s/.*\"$1\"[[:space:]]+\"([^\"]*)\".*/\1/p" "$XORG_KB" 2>/dev/null | head -1
}

apply_keyboard_layout() {
    if [ ! -f "$XORG_KB" ]; then
        log "no $XORG_KB — keeping the config.json default layout"
        return 0
    fi
    local layout variant cfg tmp
    # Comma-joined for non-ASCII layouts (us,ru); Hyprland takes that form too.
    layout="$(xkb_option XkbLayout | tr -cd 'a-z0-9,_-')"
    variant="$(xkb_option XkbVariant | tr -cd 'a-z0-9,_-')"
    if [ -z "$layout" ]; then
        log "no XkbLayout in $XORG_KB — keeping the config.json default layout"
        return 0
    fi

    cfg="${USER_HOME}/.config/modern/config.json"
    if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
        tmp="$(mktemp "${cfg}.XXXXXX")"
        if jq --arg l "$layout" --arg v "$variant" \
            '.input.kbLayout = $l | .input.kbVariant = $v' "$cfg" >"$tmp"; then
            chown "$USERNAME:$USERNAME" "$tmp" 2>/dev/null || true
            chmod 0644 "$tmp"
            mv -f "$tmp" "$cfg"
            log "keyboard layout '$layout' variant '$variant' -> $cfg"
        else
            rm -f "$tmp"
            log "WARN: jq could not set the keyboard layout in $cfg"
        fi
    else
        log "WARN: no $cfg or no jq — the desktop keeps the default layout"
    fi

    # provision installs this file fresh on every run, so appending is idempotent.
    if [ -f "$GREETD_LUA" ]; then
        printf 'hl.config({ input = { kb_layout = "%s", kb_variant = "%s" } })\n' \
            "$layout" "$variant" >>"$GREETD_LUA"
        log "keyboard layout '$layout' -> $GREETD_LUA"
    fi
}

apply_keyboard_layout

wp="${USER_HOME}/.config/modern/wallpapers/default.jpg"
if [ -f "$PROVISION_ROOT/scripts/wallpaper-sync.sh" ] && [ -f "$wp" ]; then
    runuser -u "$USERNAME" -- env \
        HOME="$USER_HOME" \
        XDG_STATE_HOME="${USER_HOME}/.local/state" \
        bash "$PROVISION_ROOT/scripts/wallpaper-sync.sh" "$wp" || true
fi
install -d -m 2775 /var/lib/modern/session
printf '%s\n' "$USERNAME" >/var/lib/modern/session/default-user
chown root:modern /var/lib/modern/session/default-user || true
chmod 0644 /var/lib/modern/session/default-user

for g in wheel video input audio render seat i2c; do
    if getent group "$g" >/dev/null 2>&1; then
        usermod -aG "$g" "$USERNAME" || true
    fi
done

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$USERNAME" || true
fi

gpu="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA compatible controller|3D controller/{print; exit}')"
if printf '%s' "$gpu" | grep -qi nvidia; then
    log "NVIDIA GPU — applying modeset and initramfs modules"
    nvidia_apply /
else
    log "non-NVIDIA GPU — skipping NVIDIA drop-ins"
fi

rm -f /etc/sudoers.d/99-modern-calamares
log "provision complete for $USERNAME"
