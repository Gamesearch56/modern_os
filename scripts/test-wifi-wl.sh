#!/usr/bin/env bash
# wifi_needs_wl matches the proprietary Broadcom ids and ignores the rest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-wifi-wl: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-wifi-wl: ok %s\n' "$*"; }

# shellcheck source=../install/lib/wifi-wl.sh
source "$ROOT/install/lib/wifi-wl.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pci() {
    local id="$1" vendor="$2" device="$3" class="$4"
    install -d "$TMP/$id"
    printf '%s\n' "$vendor" >"$TMP/$id/vendor"
    printf '%s\n' "$device" >"$TMP/$id/device"
    printf '%s\n' "$class" >"$TMP/$id/class"
}

pci 0000:01:00.0 0x14e4 0x43a0 0x028000
if WIFI_PCI_ROOT="$TMP" wifi_needs_wl; then
    ok "BCM4360 is a wl chip"
else
    err "BCM4360 (14e4:43a0) must need wl"
fi
rm -rf "$TMP"
mkdir -p "$TMP"

pci 0000:02:00.0 0x14e4 0x43a3 0x028000
if WIFI_PCI_ROOT="$TMP" wifi_needs_wl; then
    err "an unlisted Broadcom wifi id must stay on the in-tree driver"
else
    ok "unlisted Broadcom wifi is not wl"
fi
rm -rf "$TMP"
mkdir -p "$TMP"

pci 0000:03:00.0 0x8086 0x2723 0x028000
if WIFI_PCI_ROOT="$TMP" wifi_needs_wl; then
    err "Intel wifi must not select wl"
else
    ok "Intel wifi is not wl"
fi
rm -rf "$TMP"
mkdir -p "$TMP"

pci 0000:04:00.0 0x14e4 0x43a0 0x020000
if WIFI_PCI_ROOT="$TMP" wifi_needs_wl; then
    err "a Broadcom ethernet function must not select wl"
else
    ok "Broadcom ethernet is not wl"
fi

rm -rf "$TMP"
mkdir -p "$TMP"
pci 0000:05:00.0 0x14e4 0x4365 0x028000
if WIFI_PCI_ROOT="$TMP" wifi_needs_wl; then
    ok "BCM43142 is a wl chip"
else
    err "BCM43142 (14e4:4365) must need wl"
fi

grep -F 'wifi_needs_wl' "$ROOT/install/lib/pkg.sh" >/dev/null \
    || err "detect_wifi_wl must use wifi_needs_wl"

# live-wifi-up.sh names what keeps the Network step empty. Stubs keep it
# off the real radio, systemd and NetworkManager.
UP="$ROOT/iso/airootfs/usr/lib/modern/live-wifi-up.sh"
STUB="$TMP/stub"
mkdir -p "$STUB" "$TMP/net"
for b in systemctl ip modprobe; do
    printf '#!/bin/sh\nexit 0\n' >"$STUB/$b"
done
# shellcheck disable=SC2016
printf '#!/bin/sh\n[ "$1 $2" = "radio wifi" ] && [ -z "$3" ] && echo enabled\nexit 0\n' >"$STUB/nmcli"
# shellcheck disable=SC2016
printf '#!/bin/sh\n[ "$1" = -n ] && cat "%s/rfkill" 2>/dev/null\nexit 0\n' "$TMP" >"$STUB/rfkill"
chmod +x "$STUB"/*
up() {
    PATH="$STUB:$PATH" WIFI_SYS_NET="$TMP/net" WIFI_PCI_ROOT="$TMP" WIFI_STATE_DIR="$TMP/state" \
        "$UP" | tail -n 1
}

if [ "$(up)" = "nodriver 14e4:4365" ]; then
    ok "a Wi-Fi chip without an interface is reported with its id"
else
    err "driverless chip reported as '$(up)'"
fi
mkdir -p "$TMP/0000:05:00.0/net" "$TMP/net/wlan0/wireless"
if [ "$(up)" = ok ]; then
    ok "a radio with an interface is ok"
else
    err "working radio reported as '$(up)'"
fi
printf 'wlan blocked\n' >"$TMP/rfkill"
if [ "$(up)" = blocked ]; then
    ok "a hardware-blocked radio is reported"
else
    err "hard block reported as '$(up)'"
fi
rm -rf "$TMP/net/wlan0" "$TMP/0000:05:00.0" "$TMP/rfkill"
if [ "$(up)" = none ]; then
    ok "no adapter at all is reported"
else
    err "no adapter reported as '$(up)'"
fi
[ "$(cat "$TMP/state/wifi-state" 2>/dev/null)" = none ] \
    || err "the state file the Network step reads was not written"
for f in iso/airootfs/usr/lib/modern/live-setup.sh iso/releng/calamares-modernnet/ModernNetNm.cpp \
    scripts/iso-build.sh iso/releng/profiledef.sh; do
    grep -F 'live-wifi-up.sh' "$ROOT/$f" >/dev/null || err "$f must use live-wifi-up.sh"
done

if [ "$FAIL" -eq 0 ]; then
    ok "done"
else
    exit 1
fi
