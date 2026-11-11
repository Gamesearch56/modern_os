#!/usr/bin/env bash
# The kernel preset must name /boot/vmlinuz-linux-zen, and an upgrade must
# boot that kernel rather than a versioned entry whose modules are gone.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/install/lib/kernel-boot.sh"
FAIL=0
err() { printf 'test-kernel-boot: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-kernel-boot: ok %s\n' "$*"; }

[ -f "$LIB" ] || { printf 'test-kernel-boot: missing %s\n' "$LIB" >&2; exit 1; }

# shellcheck source=../install/lib/kernel-boot.sh
source "$LIB"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-kboot-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# shellcheck disable=SC2016 # the installer line is a literal, not this script's expansion
needle='source "$REPO_ROOT/install/lib/kernel-boot.sh"'
if grep -qF "$needle" "$ROOT/install/install.sh" \
    && grep -q 'kernel_boot_apply' "$ROOT/install/install.sh" \
    && grep -q 'kernel-boot deferred to the update'"'"'s root step' "$ROOT/install/install.sh"; then
    ok "install.sh pins the kernel before a live boot and defers it for Settings"
else
    err "install.sh must source kernel-boot.sh, apply it, and defer under MODERN_ROOT_PLAN"
fi

if awk '
        /kernel_boot_prepare/ { prep = NR }
        /PACMAN" -Syu/ { pac = NR }
        /kernel_boot_reconcile/ { rec = NR }
        END { exit !(prep && pac && rec && prep < pac && pac < rec) }
    ' "$ROOT/scripts/update-apply.sh"; then
    ok "the package update pins the preset before pacman and reconciles after"
else
    err "update-apply.sh must prepare the preset before pacman -Syu and reconcile after"
fi

export KERNEL_BOOT_ROOT="$TMP"
mkdir -p "$TMP/usr/lib/modules/7.2.15-zen1-1-zen"
printf 'linux-zen\n' >"$TMP/usr/lib/modules/7.2.15-zen1-1-zen/pkgbase"
printf 'new-kernel\n' >"$TMP/usr/lib/modules/7.2.15-zen1-1-zen/vmlinuz"
kernel_boot_preset_pin
if [ "$(grep -c '^ALL_kver=' "$TMP/etc/mkinitcpio.d/linux-zen.preset")" -eq 1 ] \
    && grep -qx 'ALL_kver="/boot/vmlinuz-linux-zen"' "$TMP/etc/mkinitcpio.d/linux-zen.preset"; then
    ok "a missing preset is written with the stable kernel path"
else
    err "preset pin did not write ALL_kver"
fi
kernel_boot_preset_pin
if [ "$(grep -c '^ALL_kver=' "$TMP/etc/mkinitcpio.d/linux-zen.preset")" -eq 1 ]; then
    ok "pinning the preset twice does not duplicate ALL_kver"
else
    err "preset pin duplicated ALL_kver"
fi

printf 'ALL_kver="/usr/lib/modules/7.2.14-zen1-1-zen/vmlinuz"\nPRESETS=('"'default'"')\n' \
    >"$TMP/etc/mkinitcpio.d/linux-zen.preset"
kernel_boot_preset_pin
if grep -qx 'ALL_kver="/boot/vmlinuz-linux-zen"' "$TMP/etc/mkinitcpio.d/linux-zen.preset" \
    && ! grep -q '7.2.14' "$TMP/etc/mkinitcpio.d/linux-zen.preset"; then
    ok "a versioned ALL_kver is replaced with the stable path"
else
    err "preset pin left a versioned ALL_kver in place"
fi

MK="$TMP/mkinitcpio"
cat >"$MK" <<'EOF'
#!/bin/sh
out=""
while [ $# -gt 0 ]; do
    if [ "$1" = -g ]; then
        out=$2
        shift 2
        continue
    fi
    shift
done
mkdir -p "$(dirname "$out")"
printf 'image %s\n' "$out" >"$out"
printf '%s\n' "$out" >>"${KERNEL_BOOT_LOG:?}"
EOF
chmod +x "$MK"

mkdir -p "$TMP/boot/loader/entries" "$TMP/boot/deadbeef/7.2.14-zen1-1-zen"
printf 'old-kernel\n' >"$TMP/boot/deadbeef/7.2.14-zen1-1-zen/linux"
printf 'timeout 5\n' >"$TMP/boot/loader/loader.conf"
cat >"$TMP/boot/loader/entries/deadbeef-7.2.14-zen1-1-zen.conf" <<'EOF'
title   Old kernel
version 7.2.14-zen1-1-zen
linux   /deadbeef/7.2.14-zen1-1-zen/linux
options quiet splash
EOF
export KERNEL_BOOT_MKINITCPIO="$MK" KERNEL_BOOT_LOG="$TMP/mk.log"
: >"$KERNEL_BOOT_LOG"
kernel_boot_reconcile
if grep -q 'initramfs-linux-zen.img' "$KERNEL_BOOT_LOG" \
    && cmp -s "$TMP/usr/lib/modules/7.2.15-zen1-1-zen/vmlinuz" "$TMP/boot/vmlinuz-linux-zen" \
    && grep -q 'default modern.conf' "$TMP/boot/loader/loader.conf" \
    && grep -q 'timeout 5' "$TMP/boot/loader/loader.conf" \
    && grep -q 'options quiet splash' "$TMP/boot/loader/entries/modern.conf" \
    && [ ! -e "$TMP/boot/loader/entries/deadbeef-7.2.14-zen1-1-zen.conf" ] \
    && [ ! -d "$TMP/boot/deadbeef/7.2.14-zen1-1-zen" ] \
    && [ -f "$TMP/boot/initramfs-linux-zen-fallback.img" ]; then
    ok "reconcile builds the installed kernel and drops the entry whose modules are gone"
else
    err "reconcile did not switch the boot menu onto 7.2.15"
fi

: >"$KERNEL_BOOT_LOG"
kernel_boot_reconcile
if [ ! -s "$KERNEL_BOOT_LOG" ] \
    && grep -q 'options quiet splash' "$TMP/boot/loader/entries/modern.conf"; then
    ok "a matching kernel image is not rebuilt and keeps its command line"
else
    err "reconcile rebuilt an initramfs that already matched, or dropped the command line"
fi

printf 'old-kernel\n' >"$TMP/boot/vmlinuz-linux-zen"
cat >"$MK" <<'EOF'
#!/bin/sh
echo fail >>"${KERNEL_BOOT_LOG:?}"
exit 1
EOF
: >"$KERNEL_BOOT_LOG"
if kernel_boot_reconcile; then
    err "a failed initramfs build must not succeed"
else
    if cmp -s "$TMP/boot/vmlinuz-linux-zen" <(printf 'old-kernel\n'); then
        ok "a failed initramfs build puts the previous kernel file back"
    else
        err "a failed initramfs build left the new kernel in /boot"
    fi
fi

kernel_boot_install_hooks
if [ -x "$TMP/usr/lib/modern/kernel-boot.sh" ] \
    && grep -q 'kernel-boot.sh preset' "$TMP/etc/pacman.d/hooks/89-modern-kernel-preset.hook" \
    && grep -q 'kernel-boot.sh boot' "$TMP/etc/pacman.d/hooks/95-modern-kernel-boot.hook"; then
    ok "pacman hooks pin the preset before the initramfs hook and fix the menu after"
else
    err "kernel pacman hooks were not installed"
fi

# Pacman runs hooks in filename order. 89 must precede mkinitcpio's 90
# hook so the preset is pinned first; 95 must follow it.
got="$(printf '%s\n' 89-modern-kernel-preset.hook 90-mkinitcpio-install.hook 95-modern-kernel-boot.hook | sort | paste -sd' ' -)"
if [ "$got" = "89-modern-kernel-preset.hook 90-mkinitcpio-install.hook 95-modern-kernel-boot.hook" ]; then
    ok "hook names sit on either side of the initramfs rebuild"
else
    err "hook names do not bracket 90-mkinitcpio-install.hook ($got)"
fi

# The kernel this session booted stays on the menu. An older one, whose
# modules are already gone, does not.
export KERNEL_BOOT_RUNNING="7.2.14-zen1-1-zen"
mkdir -p "$TMP/boot/deadbeef/7.2.14-zen1-1-zen" "$TMP/boot/deadbeef/7.2.12-zen1-1-zen"
printf 'running-kernel\n' >"$TMP/boot/deadbeef/7.2.14-zen1-1-zen/linux"
printf 'older-kernel\n' >"$TMP/boot/deadbeef/7.2.12-zen1-1-zen/linux"
printf 'initrd-7.2.14\n' >"$TMP/boot/deadbeef/7.2.14-zen1-1-zen/initrd"
cat >"$TMP/boot/loader/entries/deadbeef-7.2.14-zen1-1-zen.conf" <<'EOF'
title   Running
version 7.2.14-zen1-1-zen
linux   /deadbeef/7.2.14-zen1-1-zen/linux
initrd  /deadbeef/7.2.14-zen1-1-zen/initrd
options quiet splash
EOF
cat >"$TMP/boot/loader/entries/deadbeef-7.2.12-zen1-1-zen.conf" <<'EOF'
title   Older
version 7.2.12-zen1-1-zen
linux   /deadbeef/7.2.12-zen1-1-zen/linux
options quiet splash
EOF
kernel_boot_drop_stale "$TMP"
if [ -f "$TMP/boot/loader/entries/deadbeef-7.2.14-zen1-1-zen.conf" ] \
    && [ -f "$TMP/boot/deadbeef/7.2.14-zen1-1-zen/linux" ] \
    && [ ! -e "$TMP/boot/loader/entries/deadbeef-7.2.12-zen1-1-zen.conf" ] \
    && [ ! -d "$TMP/boot/deadbeef/7.2.12-zen1-1-zen" ]; then
    ok "the running kernel stays selectable and an older entry is removed"
else
    err "drop_stale kept or removed the wrong kernel entries"
fi

mkdir -p "$TMP/usr/lib/modules/7.2.14-zen1-1-zen"
printf 'linux-zen\n' >"$TMP/usr/lib/modules/7.2.14-zen1-1-zen/pkgbase"
cp -a "$TMP/boot/deadbeef/7.2.14-zen1-1-zen/linux" "$TMP/usr/lib/modules/7.2.14-zen1-1-zen/vmlinuz"
kernel_boot_shelter
if cmp -s "$TMP/boot/modern-keep/vmlinuz" "$TMP/boot/deadbeef/7.2.14-zen1-1-zen/linux" \
    && cmp -s "$TMP/boot/modern-keep/initramfs.img" "$TMP/boot/deadbeef/7.2.14-zen1-1-zen/initrd" \
    && grep -q 'linux   /modern-keep/vmlinuz' "$TMP/boot/loader/entries/modern-keep.conf" \
    && grep -q 'options quiet splash' "$TMP/boot/loader/entries/modern-keep.conf"; then
    ok "the running kernel is copied aside before an upgrade"
else
    err "recovery kernel was not shelved"
fi
rm -rf "$TMP/usr/lib/modules/7.2.14-zen1-1-zen"
kernel_boot_shelter
if cmp -s "$TMP/boot/modern-keep/vmlinuz" "$TMP/boot/deadbeef/7.2.14-zen1-1-zen/linux"; then
    ok "a boot with no modules does not replace the recovery kernel"
else
    err "shelter overwrote the recovery kernel while this boot has no modules"
fi
printf 'not-a-kernel\n' >"$TMP/boot/modern-keep/vmlinuz"
kernel_boot_drop_stale "$TMP"
if cmp -s "$TMP/boot/modern-keep/vmlinuz" <(printf 'not-a-kernel\n') \
    && [ -f "$TMP/boot/loader/entries/modern-keep.conf" ]; then
    ok "the recovery kernel is not treated as a stale entry"
else
    err "drop_stale removed the recovery kernel"
fi
printf 'running-kernel\n' >"$TMP/boot/modern-keep/vmlinuz"
unset KERNEL_BOOT_RUNNING
cp -a "$TMP/usr/lib/modules/7.2.15-zen1-1-zen/vmlinuz" "$TMP/boot/vmlinuz-linux-zen"

if kernel_boot_needs_repair; then
    err "a matched kernel and preset must not ask for a boot repair"
else
    ok "a matched kernel does not ask for a boot repair"
fi
mkdir -p "$TMP/var/lib/modern"
printf '42\n' >"$TMP/var/lib/modern/update-snapshot"
if kernel_boot_needs_repair; then
    ok "an interrupted update asks for a boot repair"
else
    err "an update mark did not ask for a boot repair"
fi
rm -f "$TMP/var/lib/modern/update-snapshot"
export KERNEL_BOOT_RUNNING="9.9.9-zen1-1-zen"
if kernel_boot_needs_repair; then
    ok "a running kernel with no modules asks for a boot repair"
else
    err "missing modules did not ask for a boot repair"
fi
unset KERNEL_BOOT_RUNNING

cat >"$TMP/bootctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"${KERNEL_BOOT_BOOTCTL_LOG:?}"
exit 0
EOF
chmod +x "$TMP/bootctl"
export KERNEL_BOOT_BOOTCTL="$TMP/bootctl" KERNEL_BOOT_BOOTCTL_LOG="$TMP/bootctl.log"
: >"$KERNEL_BOOT_BOOTCTL_LOG"
kernel_boot_reconcile
if [ "$(cat "$KERNEL_BOOT_BOOTCTL_LOG")" = "set-oneshot modern.conf" ] \
    && grep -qx 'default modern-keep.conf' "$TMP/boot/loader/loader.conf" \
    && grep -q 'timeout 5' "$TMP/boot/loader/loader.conf"; then
    ok "a failed new kernel falls back to the recovery entry"
else
    err "oneshot did not keep the recovery kernel as the default: $(cat "$TMP/boot/loader/loader.conf" "$KERNEL_BOOT_BOOTCTL_LOG")"
fi
export KERNEL_BOOT_RUNNING="7.2.15-zen1-1-zen"
kernel_boot_confirm
if grep -qx 'default modern.conf' "$TMP/boot/loader/loader.conf"; then
    ok "a kernel that reached userspace becomes the default"
else
    err "confirm did not keep the installed kernel"
fi
unset KERNEL_BOOT_RUNNING KERNEL_BOOT_BOOTCTL

if [ -f "$TMP/etc/systemd/system/modern-boot-confirm.service" ] \
    && grep -q 'kernel-boot.sh confirm' "$TMP/etc/systemd/system/modern-boot-confirm.service"; then
    ok "userspace confirms the kernel it actually booted"
else
    err "boot confirm service was not installed"
fi

[ "$FAIL" -eq 0 ]
printf 'test-kernel-boot: ok\n'
