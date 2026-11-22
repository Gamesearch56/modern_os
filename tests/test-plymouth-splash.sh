#!/usr/bin/env bash
# Splash is a solid theme. Applying it keeps root= and does not rebuild
# from install.sh, a palette change, or a wallpaper change.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-plymouth-splash: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-plymouth-splash: ok %s\n' "$*"; }

THEME="$ROOT/install/system/plymouth/modern/modern.script"
APPLY="$ROOT/install/system/plymouth/apply.sh"
PROVISION="$ROOT/install/system/provision-iso.sh"
NVIDIA="$ROOT/install/system/nvidia/apply.sh"
BOOT="$ROOT/iso/airootfs/etc/calamares/modules/bootloader.conf"
INSTALL="$ROOT/install/install.sh"
THEME_APPLY="$ROOT/scripts/theme-apply.sh"
WALL="$ROOT/scripts/wallpaper-sync.sh"
GREETER="$ROOT/stow/greeter/.config/quickshell/greeter/SessionSurface.qml"
START="$ROOT/stow/hypr/.config/hypr/modules/autostart.lua"

if grep -Fq 'Image.Text("ModernOS", 0.8157, 0.7373, 1.0, 1.0, "Sans 120", "center")' "$THEME" \
    && grep -Fq 'SetBackgroundTopColor(0.0784, 0.0706, 0.0941)' "$THEME" \
    && grep -Fq 'Math.Cos' "$THEME" \
    && grep -Fq 'SetOpacity' "$THEME" \
    && ! grep -Fq 'Image.Box' "$THEME" \
    && ! grep -Eq '\.jpg|\.png' "$THEME"; then
    ok "splash is a solid surface, a large title, and a spinner, with no image"
else
    err "modern.script must stay a solid splash with no wallpaper file"
fi

UPDATE="$ROOT/scripts/update-apply.sh"
if ! grep -Fq 'plymouth_apply' "$INSTALL" \
    && grep -Fq "printf 'splash\\n'" "$INSTALL" \
    && grep -Fq 'plymouth_apply /' "$UPDATE" \
    && grep -Fq 'plymouth_rebuild' "$UPDATE" \
    && ! grep -Fq 'mkinitcpio -P' "$THEME_APPLY" \
    && ! grep -Fq 'mkinitcpio -P' "$WALL" \
    && grep -Fq 'plymouth_apply /' "$PROVISION" \
    && grep -Fq 'mkinitcpio -P' "$PROVISION" \
    && ! grep -Fq 'mkinitcpio -P' "$NVIDIA" \
    && grep -Fq 'splash' "$BOOT" \
    && grep -Fq 'loglevel=3' "$BOOT" \
    && grep -Fq 'plymouth' "$ROOT/install/manifests/10-desktop.txt"; then
    ok "a system update enables the splash; palette and wallpaper do not rebuild"
else
    err "splash must be enabled by the update plan, not by a theme or wallpaper change"
fi

if grep -Fq 'root._launching' "$GREETER" \
    && grep -Fq 'session.signingIn' "$GREETER" \
    && grep -Fq 'splash_quit' "$START" \
    && grep -Fq 'plymouth quit --retain-splash' "$START" \
    && ! grep -Fq 'plymouth show-splash' "$START"; then
    ok "sign-in keeps the wallpaper, then the desktop quits the splash"
else
    err "greeter must cover with the wallpaper, and autostart must quit plymouth"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-plymouth-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/etc/mkinitcpio.conf.d" "$TMP/boot/loader/entries" "$TMP/etc/kernel"
printf '%s\n' 'HOOKS=(base udev autodetect microcode kms keyboard keymap consolefont block filesystems fsck)' \
    >"$TMP/etc/mkinitcpio.conf"
printf '%s\n' 'title   ModernOS' 'linux   /vmlinuz-linux-zen' \
    'options quiet root=UUID=abc rw nvidia-drm.modeset=1' \
    >"$TMP/boot/loader/entries/modern.conf"
printf '%s\n' 'quiet root=UUID=abc rw i915.fastboot=1' >"$TMP/etc/kernel/cmdline"

# Declared here: the apply script assigns it, and shellcheck does not
# follow a sourced path it was told to skip.
plymouth_rebuild=0
# shellcheck disable=SC1090
source "$APPLY"
plymouth_apply "$TMP"
if [ "$plymouth_rebuild" -eq 1 ]; then
    ok "a new theme asks for one initramfs rebuild"
else
    err "first apply must set plymouth_rebuild"
fi
plymouth_apply "$TMP"
if [ "$plymouth_rebuild" -eq 0 ]; then
    ok "an unchanged splash does not rebuild again"
else
    err "second apply must leave plymouth_rebuild at 0"
fi

hooks="$(grep '^HOOKS=' "$TMP/etc/mkinitcpio.conf")"
if [ "$hooks" = "HOOKS=(base udev autodetect microcode kms plymouth keyboard keymap consolefont block filesystems fsck)" ]; then
    ok "plymouth hook is once, immediately after kms"
else
    err "HOOKS line: $hooks"
fi

opts="$(grep '^options ' "$TMP/boot/loader/entries/modern.conf")"
if printf '%s\n' "$opts" | grep -q 'root=UUID=abc' \
    && printf '%s\n' "$opts" | grep -q 'nvidia-drm.modeset=1' \
    && printf '%s\n' "$opts" | grep -q 'splash' \
    && printf '%s\n' "$opts" | grep -q 'loglevel=3' \
    && printf '%s\n' "$opts" | grep -q 'systemd.show_status=0' \
    && printf '%s\n' "$opts" | grep -q 'rd.systemd.show_status=0' \
    && ! printf '%s\n' "$opts" | grep -q 'systemd.show_status=auto' \
    && ! printf '%s\n' "$opts" | grep -q 'i915.fastboot' \
    && printf '%s\n' "$opts" | grep -q 'i915.enable_psr=0' \
    && [ "$(printf '%s\n' "$opts" | grep -o 'splash' | wc -l)" -eq 1 ] \
    && [ "$(printf '%s\n' "$opts" | grep -o 'i915.enable_psr=0' | wc -l)" -eq 1 ]; then
    ok "boot entry keeps root= and gains splash once"
else
    err "boot entry options: $opts"
fi

cmd="$(cat "$TMP/etc/kernel/cmdline")"
if printf '%s\n' "$cmd" | grep -q 'root=UUID=abc' \
    && printf '%s\n' "$cmd" | grep -q 'splash' \
    && printf '%s\n' "$cmd" | grep -q 'systemd.show_status=0' \
    && ! printf '%s\n' "$cmd" | grep -q 'i915.fastboot' \
    && printf '%s\n' "$cmd" | grep -q 'i915.enable_psr=0' \
    && [ "$(printf '%s\n' "$cmd" | grep -o 'loglevel=3' | wc -l)" -eq 1 ] \
    && [ "$(printf '%s\n' "$cmd" | grep -o 'i915.enable_psr=0' | wc -l)" -eq 1 ]; then
    ok "kernel cmdline keeps the root device and drops the ignored fastboot parameter"
else
    err "kernel cmdline: $cmd"
fi

mkdir -p "$TMP/etc/systemd/system/greetd.service.d"
printf '%s\n' 'Conflicts=plymouth-quit.service' \
    >"$TMP/etc/systemd/system/greetd.service.d/plymouth.conf"
printf '%s\n' 'AQ_NO_ATOMIC=1' >"$TMP/usr/lib/modern/display-handoff.sh"
printf '%s\n' '[Service]' >"$TMP/etc/systemd/system/modern-plymouth-handoff.service"
plymouth_apply "$TMP"
if [ -f "$TMP/etc/systemd/system/plymouth-quit.service.d/retain.conf" ] \
    && grep -Fq 'quit --retain-splash' "$TMP/etc/systemd/system/plymouth-quit.service.d/retain.conf" \
    && [ ! -e "$TMP/etc/systemd/system/greetd.service.d/plymouth.conf" ] \
    && [ ! -e "$TMP/usr/lib/modern/display-handoff.sh" ] \
    && [ ! -e "$TMP/etc/systemd/system/modern-plymouth-handoff.service" ] \
    && ! grep -Fq 'display-handoff.sh' "$ROOT/install/system/greetd/kiosk.sh" \
    && [ -x "$TMP/usr/lib/modern/splash-hold.sh" ] \
    && ! grep -Fq 'modern-splash.service' "$ROOT/scripts/splash-hold.sh" \
    && [ -f "$TMP/etc/systemd/system/modern-splash.service" ]; then
    ok "quit keeps the splash frame, and an update removes the held splash"
else
    err "plymouth apply must not hold the login screen behind the splash"
fi

if [ -f "$TMP/usr/share/plymouth/themes/modern/modern.script" ] \
    && [ "$(readlink "$TMP/usr/share/plymouth/themes/default.plymouth")" = "modern/modern.plymouth" ] \
    && grep -q '^Theme=modern$' "$TMP/etc/plymouth/plymouthd.conf" \
    && ! find "$TMP/usr/share/plymouth/themes/modern" -name '*.jpg' | grep -q .; then
    ok "theme install is the script only"
else
    err "theme was not installed as a solid script"
fi

printf '%s\n' 'HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block filesystems fsck)' \
    >"$TMP/etc/mkinitcpio.conf"
plymouth_apply "$TMP"
hooks="$(grep '^HOOKS=' "$TMP/etc/mkinitcpio.conf")"
if [ "$hooks" = "HOOKS=(base systemd autodetect microcode modconf kms plymouth keyboard keymap sd-vconsole block filesystems fsck)" ]; then
    ok "systemd hook line keeps its modules"
else
    err "systemd HOOKS line: $hooks"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-plymouth-splash: ok\n'
