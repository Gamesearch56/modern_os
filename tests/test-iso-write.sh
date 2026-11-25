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

if run "$ONE" --dry-run --iso 'https://example.invalid/modernos-v0.0.0-x86_64.iso' >/dev/null 2>"$TMP/url.err"; then
    err "a bad link was accepted"
elif grep -F 'could not download' "$TMP/url.err" >/dev/null; then
    ok "a link is downloaded instead of the newest local image"
else
    err "a link was not downloaded: $(cat "$TMP/url.err")"
fi

CACHE="$TMP/cache/modern-v1.2.3/iso/out"
mkdir -p "$CACHE"
cp "$ISO" "$CACHE/modernos-v1.2.3-x86_64.iso"
out="$(XDG_CACHE_HOME="$TMP/cache" run "$ONE" --dry-run)"
if printf '%s\n' "$out" | grep -F 'modernos-v' >/dev/null \
    && printf '%s\n' "$out" | grep -F '/dev/sdb' >/dev/null; then
    ok "with no path, the newest image on this computer is used"
else
    err "newest image was not found: $out"
fi

# shellcheck source=../scripts/lib/iso-images.sh
source "$ROOT/scripts/lib/iso-images.sh"
pick="$TMP/pick"
mkdir -p "$pick/repo/iso/out" "$pick/home/.cache/modern-v0810/iso/out" \
    "$pick/home/.cache/modern-v0811/iso/out"
release_iso="$pick/home/.cache/modern-v0810/iso/out/modernos-v0.8.10-x86_64.iso"
local_iso="$pick/repo/iso/out/modernos-v0.8.10-x86_64.iso"
: >"$release_iso"
touch -d '2020-01-01 00:00:00' "$release_iso"
: >"$local_iso"
chosen="$(HOME="$pick/home" XDG_CACHE_HOME="$pick/home/.cache" iso_newest_release "$pick/repo")"
if [ "$chosen" = "$local_iso" ]; then
    ok "a local rebuild of the same version beats the release copy"
else
    err "same version chose $chosen"
fi
high_iso="$pick/home/.cache/modern-v0811/iso/out/modernos-v0.8.11-x86_64.iso"
: >"$high_iso"
touch -d '2019-01-01 00:00:00' "$high_iso"
chosen="$(HOME="$pick/home" XDG_CACHE_HOME="$pick/home/.cache" iso_newest_release "$pick/repo")"
if [ "$chosen" = "$high_iso" ]; then
    ok "a higher version still wins over a newer rebuild of an older one"
else
    err "higher version chose $chosen"
fi
mkdir -p "$pick/repo/iso/out/release/v0.8.12"
folder_iso="$pick/repo/iso/out/release/v0.8.12/modernos-x86_64.iso"
: >"$folder_iso"
touch -d '2018-01-01 00:00:00' "$folder_iso"
chosen="$(HOME="$pick/home" XDG_CACHE_HOME="$pick/home/.cache" iso_newest_release "$pick/repo")"
if [ "$chosen" = "$folder_iso" ]; then
    ok "a release folder name beats an older version in the file name"
else
    err "release folder chose $chosen"
fi
label="$(iso_image_label "$folder_iso")"
if [ "$label" = "v0.8.12/modernos-x86_64.iso" ] \
    && [ "$(iso_image_label "$high_iso")" = "modernos-v0.8.11-x86_64.iso" ]; then
    ok "a release image is printed with its folder"
else
    err "image label was $label"
fi

if grep -Fq 'iso_newest_release' "$ROOT/scripts/iso-qemu.sh" \
    && grep -Fq 'iso_newest_release' "$WRITE"; then
    ok "qemu and write share the newest release image"
else
    err "iso-qemu.sh must use the same newest-image search as iso-write.sh"
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
