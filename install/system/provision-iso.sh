#!/usr/bin/env bash
# GATED leftovers (Plymouth, NVIDIA initramfs, snapper, modern-usersd)
# stay out of install.sh. Greetd/greeter are applied by install/lib/greetd.sh.
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
# shellcheck source=plymouth/apply.sh
source "$PROVISION_ROOT/install/system/plymouth/apply.sh"
# shellcheck source=../lib/greetd.sh
source "$PROVISION_ROOT/install/lib/greetd.sh"

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

# Calamares' keyboard job writes the chosen layout to /etc/vconsole.conf and
# the X11 snippet, which covers the TTY and Xwayland clients. Neither is read
# by Hyprland (modules/input.lua takes kb_layout from config.json) or by
# greetd's own Hyprland instance; without this step a German install boots
# to a us login prompt and a us desktop.
XORG_KB="${MODERN_XORG_KB:-/etc/X11/xorg.conf.d/00-keyboard.conf}"
GREETD_LUA="${MODERN_GREETD_LUA:-/etc/greetd/hyprland.lua}"
SESSION_DIR="${MODERN_SESSION_DIR:-/var/lib/modern/session}"

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

    # Snapshot for the kiosk Hyprland (hyprland.lua reads keyboard.json).
    # Do not append to hyprland.lua — greetd_apply recopies that file and
    # Settings must be able to replace the layout without a leftover us/de.
    if mkdir -p "$SESSION_DIR" 2>/dev/null && command -v jq >/dev/null 2>&1; then
        tmp="$(mktemp "${SESSION_DIR}/keyboard.XXXXXX")"
        if jq -n --arg l "$layout" --arg v "$variant" '{layout:$l, variant:$v}' >"$tmp"; then
            chmod a+r "$tmp" || true
            mv -f "$tmp" "$SESSION_DIR/keyboard.json"
            log "keyboard layout '$layout' -> $SESSION_DIR/keyboard.json"
        else
            rm -f "$tmp"
            log "WARN: jq could not write $SESSION_DIR/keyboard.json"
        fi
    elif [ -f "$GREETD_LUA" ]; then
        printf 'hl.config({ input = { kb_layout = "%s", kb_variant = "%s" } })\n' \
            "$layout" "$variant" >>"$GREETD_LUA"
        log "keyboard layout '$layout' -> $GREETD_LUA"
    fi
}

apply_keyboard_layout

# Calamares' locale job writes LANG= to /etc/locale.conf, which is what PAM
# sessions and install/lib/i18n.sh read. Commons/I18n.qml does not: it picks
# its translation file from language.ui in config.json; without this step a
# German install has a German system locale and an English shell.
LOCALE_CONF="${MODERN_LOCALE_CONF:-/etc/locale.conf}"

locale_var() {
    sed -nE "s/^[[:space:]]*$1=[\"']?([^\"'[:space:]]+).*/\1/p" "$LOCALE_CONF" 2>/dev/null | head -1
}

# Keyed on the translation files actually shipped rather than a second list
# of supported languages: an unexpected LANG then lands on English instead of
# pointing I18n at a file that does not exist.
shell_language_for() {
    local base="${1%%.*}" code
    base="${base%%_*}"
    code="${base,,}"
    code="${code//[!a-z]/}"
    if [ -n "$code" ] && [ -f "${USER_HOME}/.config/modern/translations/${code}.json" ]; then
        printf '%s\n' "$code"
    else
        printf 'en\n'
    fi
}

apply_system_language() {
    if [ ! -f "$LOCALE_CONF" ]; then
        log "no $LOCALE_CONF — keeping the config.json default language"
        return 0
    fi
    local lang code cfg tmp
    lang="$(locale_var LANG)"
    if [ -z "$lang" ]; then
        log "no LANG in $LOCALE_CONF — keeping the config.json default language"
        return 0
    fi
    code="$(shell_language_for "$lang")"

    cfg="${USER_HOME}/.config/modern/config.json"
    if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
        tmp="$(mktemp "${cfg}.XXXXXX")"
        if jq --arg l "$code" '.language.ui = $l' "$cfg" >"$tmp"; then
            chown "$USERNAME:$USERNAME" "$tmp" 2>/dev/null || true
            chmod 0644 "$tmp"
            mv -f "$tmp" "$cfg"
            log "system locale '$lang' -> shell language '$code' in $cfg"
        else
            rm -f "$tmp"
            log "WARN: jq could not set the shell language in $cfg"
        fi
    else
        log "WARN: no $cfg or no jq — the desktop keeps the default language"
    fi
}

apply_system_language

# greetd_apply's wallpaper-sync bakes chrome.json and keyboard.json.
# Doing that before the two copies above froze the login screen on the
# stock English strings and the us layout, and a later sync that cannot
# replace those root-owned files never gets a second chance.
greetd_apply "$USERNAME"

# install.sh already seeded capture folders; re-run with the installed
# LANG so a stock ~/Pictures/Screenshots becomes ~/Bilder/Screenshots.
if [ -f "${USER_HOME}/.config/modern/config.json" ] \
    && [ -x "$PROVISION_ROOT/scripts/xdg-capture-seed.sh" ]; then
    seed_lang="$(locale_var LANG)"
    [ -n "$seed_lang" ] || seed_lang="C.UTF-8"
    runuser -u "$USERNAME" -- env \
        HOME="$USER_HOME" \
        XDG_CONFIG_HOME="${USER_HOME}/.config" \
        XDG_STATE_HOME="${USER_HOME}/.local/state" \
        LANG="$seed_lang" \
        LC_MESSAGES="$seed_lang" \
        bash "$PROVISION_ROOT/scripts/xdg-capture-seed.sh" \
        "${USER_HOME}/.config/modern/config.json" || true
fi

# Ordering, not coincidence: wallpaper-sync.sh rebakes chrome.json and
# keyboard.json from the config.json just written.
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
chmod 0664 /var/lib/modern/session/default-user

for g in wheel video input audio render seat i2c; do
    if getent group "$g" >/dev/null 2>&1; then
        usermod -aG "$g" "$USERNAME" || true
    fi
done

if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$USERNAME" || true
fi

# zram-generator is installed by 00-base and idle until this config
# exists. sysctl and the scheduler apply on the next boot; running
# sysctl here would change the live installer, not the target.
install -D -m 0644 "$PROVISION_ROOT/install/system/zram/zram-generator.conf" \
    /etc/systemd/zram-generator.conf
install -D -m 0644 "$PROVISION_ROOT/install/system/sysctl.d/99-modern-zram.conf" \
    /etc/sysctl.d/99-modern-zram.conf
install -D -m 0644 "$PROVISION_ROOT/install/system/udev/60-modern-rotational-bfq.rules" \
    /etc/udev/rules.d/60-modern-rotational-bfq.rules
log "zram swap and hard-disk scheduler staged for next boot"

log "boot splash — theme and kernel line, initramfs rebuild follows"
plymouth_apply /

gpu="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA compatible controller|3D controller/{print; exit}')"
# Pre-Turing cards run nouveau (00-hw-gpu-nvidia-legacy): putting nvidia
# modules in MODULES there fails mkinitcpio and this whole provision.
if printf '%s' "$gpu" | grep -qi nvidia && pacman -Q nvidia-utils >/dev/null 2>&1; then
    log "NVIDIA GPU — applying modeset and initramfs modules"
    nvidia_apply /
elif printf '%s' "$gpu" | grep -qi nvidia; then
    log "NVIDIA GPU on nouveau — skipping NVIDIA drop-ins"
else
    log "non-NVIDIA GPU — skipping NVIDIA drop-ins"
fi

if command -v mkinitcpio >/dev/null 2>&1; then
    log "rebuilding initramfs once"
    mkinitcpio -P
fi

rm -f /etc/sudoers.d/99-modern-calamares
log "provision complete for $USERNAME"
