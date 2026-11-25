#!/usr/bin/env bash
# Installed memory for the model-fit marks. Bytes, one fact per line.
# Graphics memory under a couple of gigabytes is still reported; the
# fit rule ignores it so a shared laptop chip is not treated as a GPU.
set -euo pipefail

ram="$(awk '/MemTotal/{print $2 * 1024; exit}' /proc/meminfo)"
case "$ram" in
    ''|*[!0-9]*) ram=0 ;;
esac

vram=0
if command -v nvidia-smi >/dev/null 2>&1; then
    while IFS= read -r raw; do
        mib="${raw// /}"
        case "$mib" in
            ''|*[!0-9]*) continue ;;
        esac
        bytes=$((mib * 1024 * 1024))
        if [ "$bytes" -gt "$vram" ]; then
            vram=$bytes
        fi
    done < <(timeout 2 nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || true)
fi

if [ "$vram" -eq 0 ]; then
    shopt -s nullglob
    for f in /sys/class/drm/card*/device/mem_info_vram_total; do
        n="$(tr -cd '0-9' < "$f" 2>/dev/null || true)"
        case "$n" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$n" -gt "$vram" ]; then
            vram=$n
        fi
    done
fi

printf 'ramBytes\t%s\nvramBytes\t%s\n' "$ram" "$vram"
