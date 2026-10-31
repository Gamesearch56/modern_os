#!/usr/bin/env bash
# iso-write.sh picks a USB disk and refuses internal drives. No real write.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRITE="$ROOT/scripts/iso-write.sh"
FAIL=0

err() { printf 'test-iso-write: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-iso-write: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-iso-write-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-iso-write: refusing protected home" >&2; exit 1 ;;
    esac
fi

ISO="$TMP/modernos-v0.5.5-x86_64.iso"
dd if=/dev/zero of="$ISO" bs=1 count=0 seek=32774 status=none
printf 'CD001' | dd of="$ISO" bs=1 seek=32769 conv=notrunc status=none

ONE='{"blockdevices":[
  {"name":"sda","size":4000000000000,"model":"Extreme 55DD","tran":"usb","type":"disk","mountpoints":[null]},
  {"name":"sdb","size":15569256448,"model":"DataTraveler 2.0","tran":"usb","type":"disk","mountpoints":[null],
   "children":[{"name":"sdb1","size":15500000000,"model":null,"tran":"usb","type":"part","mountpoints":["/run/media/stick"]}]},
  {"name":"nvme0n1","size":500000000000,"model":"CT500P310SSD8","tran":"nvme","type":"disk","mountpoints":[null]},
  {"name":"zram0","size":8000000000,"model":null,"tran":null,"type":"disk","mountpoints":[null]}
]}'
BARE='{"blockdevices":[
  {"name":"sda","size":4000000000000,"model":"Extreme 55DD","tran":"usb","type":"disk","mountpoints":[null]},
  {"name":"sdb","size":15569256448,"model":"DataTraveler 2.0","tran":"usb","type":"disk","mountpoints":[null]},
  {"name":"nvme0n1","size":500000000000,"model":"CT500P310SSD8","tran":"nvme","type":"disk","mountpoints":[null]}
]}'
TWO='{"blockdevices":[
  {"name":"sdb","size":15569256448,"model":"DataTraveler 2.0","tran":"usb","type":"disk","mountpoints":[null]},
  {"name":"sdc","size":15569256448,"model":"DataTraveler 3.0","tran":"usb","type":"disk","mountpoints":[null]}
]}'

run() {
    ISO_WRITE_LSBLK_JSON="$1" "$WRITE" "${@:2}"
}

out="$(run "$ONE" --dry-run --iso "$ISO")"
if printf '%s\n' "$out" | grep -F '/dev/sdb' >/dev/null \
    && printf '%s\n' "$out" | grep -F 'DataTraveler 2.0' >/dev/null \
    && printf '%s\n' "$out" | grep -F '/run/media/stick' >/dev/null \
    && printf '%s\n' "$out" | grep -F 'dry-run' >/dev/null; then
    ok "default target is the DataTraveler"
else
    err "default target was not the DataTraveler: $out"
fi

if run "$ONE" --dry-run --iso "$ISO" --disk /dev/nvme0n1 >/dev/null 2>&1; then
    err "nvme disk was accepted"
else
    ok "nvme disk is refused"
fi

out="$(run "$ONE" --dry-run --iso "$ISO" --disk /dev/sda)"
if printf '%s\n' "$out" | grep -F '/dev/sda' >/dev/null \
    && printf '%s\n' "$out" | grep -F 'Extreme 55DD' >/dev/null; then
    ok "an explicit other USB disk is accepted"
else
    err "explicit USB disk was not accepted: $out"
fi

if run "$ONE" --dry-run --iso "$ISO" --disk /dev/sdb1 >/dev/null 2>&1; then
    err "a partition was accepted"
else
    ok "a partition is refused"
fi

if run "$TWO" --dry-run --iso "$ISO" >/dev/null 2>&1; then
    err "two DataTravelers were accepted"
else
    ok "two DataTravelers need --disk"
fi

if printf '\n' | run "$BARE" --iso "$ISO" >/dev/null 2>&1; then
    err "a write without a terminal was accepted"
else
    ok "a write without a terminal is refused"
fi

LOG="$TMP/dd.log"
cat >"$TMP/dd-fake.sh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$ISO_WRITE_LOG"
EOF
chmod +x "$TMP/dd-fake.sh"
if ISO_WRITE_LSBLK_JSON="$BARE" ISO_WRITE_DD="$TMP/dd-fake.sh" ISO_WRITE_LOG="$LOG" \
    "$WRITE" --yes --iso "$ISO" >/dev/null \
    && grep -F 'of=/dev/sdb' "$LOG" >/dev/null \
    && grep -F 'status=progress' "$LOG" >/dev/null \
    && ! grep -F 'nvme' "$LOG" >/dev/null; then
    ok "--yes writes only the DataTraveler"
else
    err "--yes did not target /dev/sdb: $(cat "$LOG" 2>/dev/null || true)"
fi

if grep -F 'oflag=dsync' "$WRITE" >/dev/null \
    && grep -F 'tr "\r" "\n"' "$WRITE" >/dev/null; then
    ok "progress is a new line as the stick receives each block"
else
    err "progress must follow the device, one line per update"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-iso-write: ok\n'
