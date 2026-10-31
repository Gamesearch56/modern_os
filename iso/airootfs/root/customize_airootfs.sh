#!/usr/bin/env bash
# mkarchiso runs this in the image chroot after pacstrap, then deletes it.
# wl.ko has to be built against this image's linux-zen. The headers and
# the DKMS package must not stay: unpackfs would install them on every
# machine, and the package blacklists brcmfmac globally.
set -euo pipefail

# iso-build.sh bind-mounts the work directory before arch-chroot. A direct
# mkarchiso call does not, and pacman then cannot see a mount for the
# package cache (it reports a full disk). Binding here covers that path.
if ! mountpoint -q /; then
    mount --rbind / /
fi

kver=""
d=""
for d in /usr/lib/modules/*/; do
    [ "$(cat "$d/pkgbase" 2>/dev/null || true)" = linux-zen ] || continue
    kver="$(basename "$d")"
    break
done
if [ -z "$kver" ]; then
    printf 'customize_airootfs: no linux-zen module tree\n' >&2
    exit 1
fi

# archiso creates this keyring at boot (pacman-init on a tmpfs). The
# build chroot has none, so pacman -S stops with "keyring is not writable"
# after the packages have already downloaded.
install -d -m 0700 /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux

pacman --disable-sandbox -S --needed --noconfirm broadcom-wl-dkms linux-zen-headers

ko="$(find "/usr/lib/modules/$kver" -name 'wl.ko*' -print -quit)"
if [ -z "$ko" ]; then
    src="$(find /usr/src -maxdepth 1 -type d -name 'broadcom-wl-*' -print -quit)"
    ver="${src##*/broadcom-wl-}"
    if [ -z "$ver" ] || [ "$ver" = "$src" ]; then
        printf 'customize_airootfs: broadcom-wl source missing\n' >&2
        exit 1
    fi
    dkms install "broadcom-wl/${ver}" -k "$kver"
    ko="$(find "/usr/lib/modules/$kver" -name 'wl.ko*' -print -quit)"
fi
if [ -z "$ko" ]; then
    printf 'customize_airootfs: wl.ko was not built\n' >&2
    exit 1
fi

keep="$(mktemp)"
cp -a "$ko" "$keep"
name="$(basename "$ko")"

pacman --disable-sandbox -Rns --noconfirm broadcom-wl-dkms linux-zen-headers
# The live boot replaces this with its own tmpfs keyring.
rm -rf /etc/pacman.d/gnupg

install -D -m 0644 "$keep" "/usr/lib/modules/$kver/updates/$name"
rm -f "$keep"
depmod -a "$kver"

if [ -d /usr/lib/modprobe.d ]; then
    find /usr/lib/modprobe.d -name '*broadcom-wl*' -delete
fi
if [ -d /etc/modprobe.d ]; then
    find /etc/modprobe.d -name '*broadcom-wl*' -delete
fi
