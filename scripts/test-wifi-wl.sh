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

grep -F 'wifi_needs_wl' "$ROOT/install/lib/pkg.sh" >/dev/null \
    || err "detect_wifi_wl must use wifi_needs_wl"

if [ "$FAIL" -eq 0 ]; then
    ok "done"
else
    exit 1
fi
