#!/usr/bin/env bash
# Steam starts from its own launcher entry, and gets a 32-bit Vulkan
# driver for this GPU (unnamed, pacman installs lib32-vulkan-radeon).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-steam: FAIL %s\n' "$*" >&2; FAIL=1; }

for gpu in "$ROOT"/install/manifests/00-hw-gpu-*.txt; do
    family="${gpu##*/00-hw-gpu-}"
    grep -Eq '^lib32-(vulkan-|nvidia-utils)' "$ROOT/install/manifests/30-hw-gpu-${family}" 2>/dev/null \
        || err "no 32-bit Vulkan driver for Steam on ${family%.txt} (30-hw-gpu-${family})"
done
grep -Fq '30-hw-gpu-' "$ROOT/install/install.sh" || err "install.sh must install 30-hw-gpu-*"

if grep -rlE 'modern steam|scripts/steam\b' "$ROOT/stow" "$ROOT/scripts/modern" 2>/dev/null | grep -q .; then
    err "Steam must start from its own launcher, not a ModernOS wrapper"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-steam: ok\n'
