#!/usr/bin/env bash
# Boot the newest ISO under iso/out/ in QEMU. Does not run mkarchiso,
# Calamares, or provision-iso.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"

die() { printf 'iso-qemu: ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: iso-qemu.sh [--disk]

Boots the newest *.iso in iso/out/ (or $MODERN_ISO_OUT).
Always attaches iso/out/vm-disk.qcow2 (created at 64G if missing)
so Calamares has a 16 GiB+ target. --disk is accepted and ignored.
Guest serial is iso/out/vm-serial.log. Never writes outside iso/out/.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --disk) ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "install qemu-desktop (or qemu-full)"

shopt -s nullglob
isos=("$OUT"/*.iso)
shopt -u nullglob
[ ${#isos[@]} -gt 0 ] || die "no ISO in $OUT — sudo ./scripts/iso-build.sh --mkarchiso"

newest="${isos[0]}"
for f in "${isos[@]}"; do
    [[ "$f" -nt "$newest" ]] && newest="$f"
done

serial="$OUT/vm-serial.log"
: >"$serial"
args=(
    -machine q35
    -smp 4
    -m 8G
    -cdrom "$newest"
    -boot d
    -device virtio-vga-gl
    -display gtk,gl=on
    -serial "file:${serial}"
    -netdev user,id=net0
    -device virtio-net,netdev=net0
)
if [ -c /dev/kvm ]; then
    args+=(-enable-kvm -cpu host)
fi
command -v qemu-img >/dev/null 2>&1 || die "qemu-img missing"
disk="$OUT/vm-disk.qcow2"
[ -f "$disk" ] || qemu-img create -f qcow2 "$disk" 64G
args+=(-drive "file=${disk},if=virtio")

printf 'iso-qemu: %s\n' "$newest"
printf 'iso-qemu: guest serial -> %s\n' "$serial"
exec qemu-system-x86_64 "${args[@]}"
