#!/usr/bin/env bash
# install/lib/gpu-stray.sh: NVIDIA userspace is removed only on a computer
# with no NVIDIA display device and no NVIDIA kernel driver, and an update
# hands that to its root step instead of calling sudo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-gpu-stray: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-gpu-stray: ok %s\n' "$*"; }
same() { if [ "$2" = "$1" ]; then ok "$3"; else err "$3 (got: $2)"; fi; }
has() { if grep -Fq -- "$1" "$2"; then ok "$3"; else err "$3"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-gpu-stray-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
# pacman -Q succeeds for every name listed in $TMP/installed.
cat >"$TMP/bin/pacman" <<'EOF'
#!/usr/bin/env bash
[ "$1" = -Q ] && grep -qx "$2" "$INSTALLED"
EOF
cat >"$TMP/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SUDO_LOG"
EOF
chmod +x "$TMP/bin/pacman" "$TMP/bin/sudo"
export PATH="$TMP/bin:$PATH" INSTALLED="$TMP/installed" SUDO_LOG="$TMP/sudo.log"

device() {
    mkdir -p "$TMP/pci/$1"
    printf '%s\n' "$2" >"$TMP/pci/$1/vendor"
    printf '%s\n' "$3" >"$TMP/pci/$1/class"
}
export MODERN_SYSFS_PCI="$TMP/pci"

log_info() { :; }; log_warn() { :; }
run() { "$@"; }
# shellcheck source=../install/lib/gpu-stray.sh
source "$ROOT/install/lib/gpu-stray.sh"

device 0000:00:02.0 0x8086 0x030000
printf '%s\n' steam lib32-nvidia-utils nvidia-utils >"$INSTALLED"
same "lib32-nvidia-utils nvidia-utils" "$(stray_nvidia_packages | xargs)" "an Intel-only laptop lists both NVIDIA userspace packages"

device 0000:01:00.0 0x10de 0x030200
same "" "$(stray_nvidia_packages | xargs)" "a hybrid laptop's second NVIDIA GPU keeps them"
rm -rf "$TMP/pci/0000:01:00.0"

device 0000:01:00.1 0x10de 0x040300
same "lib32-nvidia-utils nvidia-utils" "$(stray_nvidia_packages | xargs)" "an NVIDIA audio function is not a GPU"

printf 'nvidia-open-dkms\n' >>"$INSTALLED"
same "" "$(stray_nvidia_packages | xargs)" "an installed NVIDIA kernel driver keeps them"

printf '%s\n' steam nvidia-utils >"$INSTALLED"
plan="$TMP/plan"
: >"$plan"
MODERN_ROOT_PLAN="$plan" DRY_RUN=0 prune_stray_nvidia
same "nvidia-stray" "$(cat "$plan")" "an update defers the removal to its root step"
if [ -e "$SUDO_LOG" ]; then err "an update does not call sudo"; else ok "an update does not call sudo"; fi

MODERN_ROOT_PLAN="" DRY_RUN=0 prune_stray_nvidia
same "pacman -Rn --noconfirm nvidia-utils" "$(cat "$SUDO_LOG")" "a terminal install removes them with sudo"

rm -f "$SUDO_LOG"
DOTFILES_ONLY=1 MODERN_ROOT_PLAN="" DRY_RUN=0 prune_stray_nvidia
if [ -e "$SUDO_LOG" ]; then err "--dotfiles-only leaves packages alone"; else ok "--dotfiles-only leaves packages alone"; fi

# shellcheck source=../scripts/lib/pkg-name.sh
source "$ROOT/scripts/lib/pkg-name.sh"
# shellcheck source=../scripts/lib/root-plan.sh
source "$ROOT/scripts/lib/root-plan.sh"
printf 'pkg lib32-vulkan-intel\nnvidia-stray\n' >"$plan"
read_root_plan "$plan"
same "1 lib32-vulkan-intel" "$ROOT_PLAN_NVIDIA_STRAY ${ROOT_PLAN_PKGS[*]}" "the root plan carries the step next to its packages"

has 'stray_nvidia_packages' "$ROOT/scripts/update-apply.sh" "root picks the package names itself"
if awk '/^install_native "\$\{native_pkgs/ { n = NR } /^prune_stray_nvidia$/ { if (n && NR > n) found = 1 } END { exit !found }' "$ROOT/install/install.sh"; then
    ok "install.sh removes them after Steam's own driver is installed"
else
    err "install.sh removes them after Steam's own driver is installed"
fi

[ "$FAIL" -eq 0 ] || exit 1
