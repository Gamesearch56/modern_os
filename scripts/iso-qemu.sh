#!/usr/bin/env bash
# Boot the newest ISO under iso/out/ in QEMU. Does not run mkarchiso,
# Calamares, or provision-iso.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
HEADLESS=0
KEEP_NVRAM=0
RESET_DISK=0
UNATTENDED=0
NO_ISO=0
WIFI_SIM=0

die() { printf 'iso-qemu: ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: iso-qemu.sh [--disk] [--headless] [--keep-nvram] [--reset-disk]
                   [--unattended] [--no-iso] [--wifi-sim]

Boots the newest *.iso in iso/out/ (or $MODERN_ISO_OUT).
Always attaches iso/out/vm-disk.qcow2 (created at 64G if missing)
so Calamares has a 16 GiB+ target. --disk is accepted and ignored.
Boots OVMF (edk2-ovmf) so the guest is UEFI; BIOS QEMU makes
Calamares take the GRUB path and the systemd-boot job raises.
Guest serial is iso/out/vm-serial.log. Never writes outside iso/out/.
--headless uses -display none (no GTK/GL) for CI smoke.

UEFI ignores -boot order=d. The CD gets bootindex 1 so a leftover
install on vm-disk.qcow2 cannot steal boot (empty root= initramfs).
Firmware NVRAM is reset each run unless --keep-nvram (needed to
reboot into a finished install). --reset-disk recreates the qcow2.
--no-iso attaches no CD at all and keeps NVRAM, so the VM boots the
installed system on vm-disk.qcow2 instead of the installer. Use it
after a successful install; a guest reboot otherwise re-runs the
firmware and the CD's bootindex sends you back into Calamares.
--unattended sets QEMU fw_cfg; the live session creates
/etc/calamares/unattended (auto-next, user modern / password modern).
--wifi-sim drops the virtio NIC (so the Network step does not take the
Ethernet branch) and sets fw_cfg so live-setup.sh runs live-wifi-sim.sh:
mac80211_hwsim radios plus WPA2 APs the installer can list. The guest
has no uplink — use this to try the Wi-Fi page, not to install.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --disk) ;;
        --headless) HEADLESS=1 ;;
        --keep-nvram) KEEP_NVRAM=1 ;;
        --reset-disk) RESET_DISK=1 ;;
        --unattended) UNATTENDED=1 ;;
        --no-iso) NO_ISO=1; KEEP_NVRAM=1 ;;
        --wifi-sim) WIFI_SIM=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "install qemu-desktop (or qemu-full)"

ovmf_code=""
ovmf_vars_src=""
for d in /usr/share/edk2/x64 /usr/share/edk2-ovmf/x64 /usr/share/OVMF/x64; do
    if [ -f "$d/OVMF_CODE.4m.fd" ]; then
        ovmf_code="$d/OVMF_CODE.4m.fd"
        ovmf_vars_src="$d/OVMF_VARS.4m.fd"
        break
    fi
    if [ -f "$d/OVMF_CODE.fd" ]; then
        ovmf_code="$d/OVMF_CODE.fd"
        ovmf_vars_src="$d/OVMF_VARS.fd"
        break
    fi
done
[ -n "$ovmf_code" ] && [ -f "$ovmf_vars_src" ] \
    || die "install edk2-ovmf (systemd-boot needs UEFI firmware in QEMU)"

newest=""
if [ "$NO_ISO" -eq 0 ]; then
    shopt -s nullglob
    isos=("$OUT"/*.iso)
    shopt -u nullglob
    [ ${#isos[@]} -gt 0 ] || die "no ISO in $OUT — sudo ./scripts/iso-build.sh --mkarchiso"

    newest="${isos[0]}"
    for f in "${isos[@]}"; do
        [[ "$f" -nt "$newest" ]] && newest="$f"
    done
fi

serial="$OUT/vm-serial.log"
: >"$serial"
command -v qemu-img >/dev/null 2>&1 || die "install qemu-img (Arch splits it from qemu-system-x86)"
disk="$OUT/vm-disk.qcow2"
if [ "$RESET_DISK" -eq 1 ] && [ -f "$disk" ]; then
    rm -f "$disk"
    printf 'iso-qemu: reset %s\n' "$disk"
fi
[ -f "$disk" ] || qemu-img create -f qcow2 "$disk" 64G
ovmf_vars="$OUT/ovmf-vars.fd"
if [ "$KEEP_NVRAM" -eq 0 ] || [ ! -f "$ovmf_vars" ]; then
    cp -- "$ovmf_vars_src" "$ovmf_vars"
fi

args=(
    -machine q35
    -smp "${MODERN_ISO_QEMU_SMP:-4}"
    -m "${MODERN_ISO_QEMU_MEM:-8G}"
    -serial "file:${serial}"
)
if [ "$WIFI_SIM" -eq 0 ]; then
    args+=(
        -netdev "user,id=net0"
        -device "virtio-net,netdev=net0"
    )
fi
if [ "$NO_ISO" -eq 0 ]; then
    args+=(
        -drive "if=none,id=cd0,media=cdrom,readonly=on,file=${newest}"
        -device "virtio-scsi-pci,id=scsi0"
        -device "scsi-cd,drive=cd0,bootindex=1"
    )
fi
args+=(
    -drive "if=none,id=hd0,file=${disk}"
    -device "virtio-blk-pci,drive=hd0,bootindex=2"
)
if [ "$HEADLESS" -eq 1 ]; then
    args+=(-vga virtio -display none)
else
    args+=(-device virtio-vga-gl -display "gtk,gl=on")
fi
if [ "$UNATTENDED" -eq 1 ]; then
    args+=(-fw_cfg "name=opt/org.modernos/unattended,string=1")
fi
if [ "$WIFI_SIM" -eq 1 ]; then
    args+=(-fw_cfg "name=opt/org.modernos/wifi-sim,string=1")
fi
if [ -c /dev/kvm ]; then
    args+=(-enable-kvm -cpu host)
fi
args+=(
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=${ovmf_code}"
    -drive "if=pflash,format=raw,unit=1,file=${ovmf_vars}"
)

if [ "$NO_ISO" -eq 1 ]; then
    printf 'iso-qemu: no CD attached — booting %s\n' "$disk"
else
    printf 'iso-qemu: %s\n' "$newest"
fi
printf 'iso-qemu: guest serial -> %s\n' "$serial"
exec qemu-system-x86_64 "${args[@]}"
