#!/usr/bin/env bash
# Load wl only for the PCI ids install.sh treats as proprietary-only.
# The module is in the image without the DKMS blacklist, so a brcmfmac
# laptop keeps the in-tree driver.
set -euo pipefail

lib=""
# /usr/lib/modern is this image's copy. The pin bundle under
# /usr/share/modern/dotfile is the release tag, which does not have
# the helper until that tag contains it.
for lib in \
    /usr/lib/modern/wifi-wl.sh \
    /usr/share/modern/dotfile/install/lib/wifi-wl.sh \
    "$(dirname "$0")/../../../../../install/lib/wifi-wl.sh"
do
    [ -f "$lib" ] || continue
    # shellcheck source=../../../../../install/lib/wifi-wl.sh
    source "$lib"
    break
done
declare -F wifi_needs_wl >/dev/null 2>&1 || exit 0
wifi_needs_wl || exit 0
if ! modinfo -n wl >/dev/null 2>&1; then
    printf 'live-wifi-wl: chip needs wl but the module is not installed\n' >&2
    exit 0
fi

# Written on the live cow overlay. unpackfs copies the squashfs, not this.
install -d -m 0755 /etc/modprobe.d
cat >/etc/modprobe.d/modern-broadcom-wl.conf <<'EOF'
blacklist b43
blacklist b43legacy
blacklist bcma
blacklist brcmsmac
blacklist brcmfmac
blacklist ssb
EOF

mod=""
for mod in brcmfmac brcmsmac b43 b43legacy bcma ssb; do
    modprobe -r "$mod" 2>/dev/null || true
done
modprobe wl
command -v udevadm >/dev/null 2>&1 && udevadm settle || true
