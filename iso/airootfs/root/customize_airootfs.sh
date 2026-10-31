#!/usr/bin/env bash
# mkarchiso runs this in the image chroot after pacstrap, then deletes it.
# wl.ko has to be built against this image's linux-zen. The headers and
# the DKMS package must not stay: unpackfs would install them on every
# machine, and the package blacklists brcmfmac globally.
set -euo pipefail

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

install -D -m 0644 "$keep" "/usr/lib/modules/$kver/updates/$name"
rm -f "$keep"
depmod -a "$kver"

if [ -d /usr/lib/modprobe.d ]; then
    find /usr/lib/modprobe.d -name '*broadcom-wl*' -delete
fi
if [ -d /etc/modprobe.d ]; then
    find /etc/modprobe.d -name '*broadcom-wl*' -delete
fi
