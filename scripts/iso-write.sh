#!/usr/bin/env bash
# Write a ModernOS hybrid ISO onto a USB disk. The default target is the
# one USB disk whose model contains DataTraveler. Device names move, so
# the model is the check. --disk chooses another USB disk. Anything that
# is not a whole USB disk is refused.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/iso-images.sh
source "$ROOT/scripts/lib/iso-images.sh"
MODEL_NEEDLE="DataTraveler"
ISO=""
DISK=""
YES=0
DRY=0

die() { printf 'iso-write: ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: iso-write.sh [--iso FILE|URL] [--disk /dev/sdX] [--yes] [--dry-run]
           iso-write.sh [FILE|URL]

Writes an image onto a USB disk. --iso may be a local file or an
https link. With no --iso, the newest image already on this computer
is used (the repo, iso/out, iso/out/release/vX.Y.Z, or the release
build cache). The release folder name is the version. Two files of
the same version use the one written last, so the image just built
in iso/out wins over the release copy. With no
--disk, the disk must be the only one whose model
contains DataTraveler. --disk may name another whole USB disk. NVMe
and partitions are refused. You must type the device name (sdb) before
anything is erased, unless --yes is given. --dry-run only prints the
choice.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --iso)
            ISO="${2:-}"
            [ -n "$ISO" ] || die "--iso needs a file"
            shift
            ;;
        --disk)
            DISK="${2:-}"
            [ -n "$DISK" ] || die "--disk needs a device"
            shift
            ;;
        --yes) YES=1 ;;
        --dry-run) DRY=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        http://*|https://*|/*|./*|*.iso)
            [ -z "$ISO" ] || die "only one image: $1"
            ISO="$1"
            ;;
        *)
            if [ -e "$1" ]; then
                [ -z "$ISO" ] || die "only one image: $1"
                ISO="$1"
            else
                die "unknown argument: $1"
            fi
            ;;
    esac
    shift
done

command -v lsblk >/dev/null 2>&1 || die "lsblk is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

lsblk_json() {
    if [ -n "${ISO_WRITE_LSBLK_JSON:-}" ]; then
        printf '%s\n' "$ISO_WRITE_LSBLK_JSON"
        return
    fi
    lsblk -J -b -o NAME,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS
}

human() {
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$1"
    else
        printf '%s bytes' "$1"
    fi
}

latest_iso() {
    local found
    found="$(iso_newest_release "$ROOT")" || die "no modernos image found. Pass --iso PATH or --iso https://…"
    printf '%s\n' "$found"
}

# A link is downloaded once into the cache. A later run reuses it when
# it is already a real ISO.
fetch_iso() {
    local url="$1" name dest magic
    case "$url" in
        https://*|http://*) ;;
        *) die "not a link: $url" ;;
    esac
    command -v curl >/dev/null 2>&1 || die "curl is required to download an image"
    name="${url%%\?*}"
    name="$(basename "$name")"
    case "$name" in
        *.iso) ;;
        *) name="modernos-download.iso" ;;
    esac
    dest="${XDG_CACHE_HOME:-$HOME/.cache}/modern/iso-write/$name"
    mkdir -p "${dest%/*}"
    if [ -f "$dest" ]; then
        magic="$(dd if="$dest" bs=1 skip=32769 count=5 2>/dev/null || true)"
        if [ "$magic" = "CD001" ]; then
            printf '%s\n' "$dest"
            return 0
        fi
        rm -f "$dest"
    fi
    printf 'iso-write: downloading %s\n' "$url" >&2
    curl -fL --retry 2 -o "$dest.partial" "$url" || {
        rm -f "$dest.partial"
        die "could not download $url"
    }
    mv -f "$dest.partial" "$dest"
    printf '%s\n' "$dest"
}

iso_ok() {
    local magic
    [ -f "$1" ] || die "ISO not found: $1"
    [ -s "$1" ] || die "ISO is empty: $1"
    # Sector 16: one type byte, then the "CD001" identifier.
    magic="$(dd if="$1" bs=1 skip=32769 count=5 2>/dev/null || true)"
    [ "$magic" = "CD001" ] || die "not a hybrid ISO (no CD001): $1"
}

# One jq program: disks only, with mountpoints collected from children.
disks_json() {
    lsblk_json | jq -c '
        def mounts:
          ((.mountpoints // []) | map(select(. != null and . != "")))
          + ((.children // []) | map(mounts) | add // []);
        [.blockdevices[]?
          | select(.type == "disk")
          | {
              name: .name,
              size: (.size // 0),
              model: (.model // ""),
              tran: (.tran // ""),
              mounts: (mounts | unique)
            }
        ]'
}

disk_field() {
    local name="$1" field="$2" json="$3"
    printf '%s\n' "$json" | jq -r --arg n "$name" --arg f "$field" '
        .[] | select(.name == $n) | .[$f] | if type == "array" then join("\n") else tostring end
    '
}

require_usb_disk() {
    local name="$1" json="$2" tran
    printf '%s\n' "$json" | jq -e --arg n "$name" '.[] | select(.name == $n)' >/dev/null \
        || die "/dev/$name is not a whole disk"
    tran="$(disk_field "$name" tran "$json")"
    [ "$tran" = "usb" ] || die "/dev/$name is $tran, not usb"
    case "$name" in
        nvme*|loop*|zram*) die "refusing /dev/$name" ;;
    esac
}

pick_datatraveler() {
    local json="$1" names
    names="$(printf '%s\n' "$json" | jq -r --arg m "$MODEL_NEEDLE" '
        .[] | select(.tran == "usb" and (.model | contains($m))) | .name
    ')"
    [ -n "$names" ] || die "no USB disk whose model contains $MODEL_NEEDLE"
    [ "$(printf '%s\n' "$names" | wc -l)" -eq 1 ] \
        || die "more than one $MODEL_NEEDLE; pass --disk"
    printf '%s\n' "$names"
}

resolve_disk_name() {
    local spec="$1"
    if [ -e "$spec" ]; then
        spec="$(readlink -f "$spec")"
    fi
    spec="${spec#/dev/}"
    case "$spec" in
        */*) die "pass a whole disk, not $spec" ;;
        "") die "--disk needs a device" ;;
    esac
    printf '%s\n' "$spec"
}

as_root() {
    if [ -n "${ISO_WRITE_DD:-}" ] || [ "$(id -u)" -eq 0 ]; then
        "$@"
        return
    fi
    sudo "$@"
}

if [ -z "$ISO" ]; then
    ISO="$(latest_iso)"
elif [[ "$ISO" == http://* || "$ISO" == https://* ]]; then
    ISO="$(fetch_iso "$ISO")"
fi
iso_ok "$ISO"
ISO="$(readlink -f "$ISO")"
ISO_SIZE="$(stat -c '%s' "$ISO")"

JSON="$(disks_json)"
if [ -n "$DISK" ]; then
    NAME="$(resolve_disk_name "$DISK")"
else
    NAME="$(pick_datatraveler "$JSON")"
fi
require_usb_disk "$NAME" "$JSON"

DEV_SIZE="$(disk_field "$NAME" size "$JSON")"
MODEL="$(disk_field "$NAME" model "$JSON")"
MOUNTS="$(disk_field "$NAME" mounts "$JSON")"
[ "$DEV_SIZE" -gt "$ISO_SIZE" ] || die "/dev/$NAME ($(human "$DEV_SIZE")) is smaller than the ISO ($(human "$ISO_SIZE"))"

printf 'iso-write: %s (%s) -> /dev/%s %s (%s)\n' \
    "$(iso_image_label "$ISO")" "$(human "$ISO_SIZE")" \
    "$NAME" "$MODEL" "$(human "$DEV_SIZE")"
mount_list=()
if [ -n "$MOUNTS" ]; then
    printf 'iso-write: will unmount:\n'
    while IFS= read -r mnt; do
        [ -n "$mnt" ] || continue
        printf '  %s\n' "$mnt"
        mount_list+=("$mnt")
    done <<< "$MOUNTS"
fi

if [ "$DRY" -eq 1 ]; then
    printf 'iso-write: dry-run, nothing written\n'
    exit 0
fi

if [ "$YES" -ne 1 ]; then
    [ -t 0 ] || die "refusing to erase /dev/$NAME without a terminal; type the name, or pass --yes"
    printf 'Type %s to erase this disk: ' "$NAME"
    IFS= read -r answer || die "no confirmation"
    [ "$answer" = "$NAME" ] || die "expected $NAME"
fi

# Re-read once more so a stick that moved names is not the write target.
JSON="$(disks_json)"
require_usb_disk "$NAME" "$JSON"
if [ -n "${ISO_WRITE_DD:-}" ]; then
    "$ISO_WRITE_DD" if="$ISO" of="/dev/$NAME" bs=4M oflag=dsync status=progress
else
    # One sudo: the copy takes longer than the password timeout, so a
    # later sync would ask again. dsync reports bytes as the stick
    # receives them. Carriage-return updates stay invisible in some
    # terminals, so each update is its own line.
    printf 'iso-write: writing\n'
    # shellcheck disable=SC2016
    as_root bash -c '
        set -euo pipefail
        if [ "$#" -gt 2 ]; then
            umount "${@:3}"
        fi
        dd if="$1" of="$2" bs=4M oflag=dsync status=progress \
            2> >(stdbuf -oL tr "\r" "\n" >&2)
        sync
    ' bash "$ISO" "/dev/$NAME" "${mount_list[@]}"
fi
printf 'iso-write: wrote %s to /dev/%s\n' "$(iso_image_label "$ISO")" "$NAME"
