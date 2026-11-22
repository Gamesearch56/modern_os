#!/usr/bin/env bash
# From a live Arch ISO: print (default) or optionally run the steps that
# turn a blank disk into a bootable modern_os install. Default is
# dry-run — nothing is partitioned unless BOTH --yes and --disk /dev/X
# are given. Reads install/hardware.conf (or hardware.conf.example).
#
# Usage:
#   bootstrap.sh [--dry-run] [--vm] [--yes] [--disk /dev/X] [--conf FILE]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/install/hardware.conf"
[ -f "$CONF" ] || CONF="$ROOT/install/hardware.conf.example"

DRY_RUN=1
ASSUME_YES=0
DISK_OVERRIDE=""
PRINT_VM=0

die() { printf 'bootstrap: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'bootstrap: %s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [--dry-run] [--vm] [--yes] [--disk /dev/X] [--conf FILE]

  --dry-run   Print the partition/pacstrap/chroot plan (default).
  --vm        Print a QEMU recipe for testing this flow; do not install.
  --yes       Required together with --disk to actually wipe a disk.
  --disk DEV  Target block device (overrides hardware.conf DISK=).
  --conf FILE hardware.conf to source (default: install/hardware.conf
              or install/hardware.conf.example).

Does NOT wipe disks unless --yes AND --disk /dev/X are both passed.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --vm) PRINT_VM=1; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        --disk)
            [ $# -ge 2 ] || die "--disk needs a device"
            DISK_OVERRIDE="$2"; shift 2 ;;
        --conf)
            [ $# -ge 2 ] || die "--conf needs a file"
            CONF="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

if [ "$PRINT_VM" -eq 1 ]; then
    cat <<'EOF'
# QEMU recipe (print-only — bootstrap.sh --vm never launches qemu).
# Create a disk image, then boot the official Arch ISO against it:

qemu-img create -f qcow2 modern-bootstrap.qcow2 64G

qemu-system-x86_64 \
  -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
  -drive file=modern-bootstrap.qcow2,if=virtio \
  -cdrom archlinux-x86_64.iso \
  -boot d \
  -device virtio-vga-gl -display gtk,gl=on \
  -netdev user,id=net0 -device virtio-net,netdev=net0

# Inside the VM, mount this repo (9p, scp, or git clone) and run:
#   ./scripts/bootstrap.sh --dry-run
# Real wipe still requires --yes --disk /dev/vda
EOF
    exit 0
fi

[ -f "$CONF" ] || die "no hardware.conf at ${CONF}"
# shellcheck disable=SC1090
source "$CONF"

DISK="${DISK_OVERRIDE:-${DISK:-}}"
HOSTNAME="${HOSTNAME:-modern}"
USERNAME="${USERNAME:-devuser}"
TIMEZONE="${TIMEZONE:-Europe/Berlin}"
LOCALE="${LOCALE:-en_US.UTF-8}"

part() {
    # nvme/mmcblk/loop/nbd use pN; sda/vda use N.
    case "$1" in
        *nvme*|*mmcblk*|*loop*|*nbd*) printf '%sp%s\n' "$1" "$2" ;;
        *) printf '%s%s\n' "$1" "$2" ;;
    esac
}

print_plan() {
    local p1 p2
    p1="$(part "${DISK:-/dev/DISK}" 1)"
    p2="$(part "${DISK:-/dev/DISK}" 2)"
    cat <<EOF
Plan (hostname=${HOSTNAME} user=${USERNAME} tz=${TIMEZONE} locale=${LOCALE} disk=${DISK:-UNSET}):

  1. partition ${DISK:-/dev/DISK}
       ${p1}  EF00  1G   ESP (FAT32)
       ${p2}  8300  rest btrfs
  2. mkfs.fat -F32 ${p1}
     mkfs.btrfs ${p2}
  3. btrfs subvolumes on ${p2}:
       @          → /
       @home      → /home
       @pkg       → /var/cache/pacman/pkg
       @log       → /var/log
       @snapshots → /.snapshots
       @swap      → swap file (see docs/BACKUP.md — never snapshot @swap)
  4. mount, pacstrap -K /mnt base linux linux-firmware btrfs-progs
  5. genfstab -U /mnt >> /mnt/etc/fstab
  6. arch-chroot /mnt  (locale, timezone, user ${USERNAME}, bootloader)
  7. chain: /mnt/home/${USERNAME}/modern_os/install/install.sh --profile m0

Default is dry-run. Wipe only with: $0 --yes --disk /dev/X
EOF
}

print_plan

if [ "$ASSUME_YES" -eq 1 ] && [ -n "$DISK" ] && [ "$DISK" != "/dev/X" ]; then
    [ -b "$DISK" ] || die "${DISK} is not a block device"
    if findmnt -n -o SOURCE / 2>/dev/null | grep -q "^${DISK}"; then
        die "refusing to target the disk that holds /"
    fi
    # The numbered plan above is the wipe/pacstrap sequence. This process
    # still does not call mkfs — a typo on a development machine would be
    # unrecoverable. On the live ISO, run those steps as root after review.
    log "--yes --disk accepted for ${DISK}; run the printed steps as root (no mkfs from this process)."
    exit 0
fi

if [ -z "$DISK" ]; then
    log "DISK= empty — dry-run only (set DISK= in hardware.conf or pass --disk)."
fi
log "dry-run complete (no disks touched, dry-run=$DRY_RUN)."
