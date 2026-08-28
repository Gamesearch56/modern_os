#!/usr/bin/env bash
# modern_dotfile installer. Idempotent: safe to re-run. Phased, so a
# failure in phase 3 doesn't repeat phases 1-2's work.
#
# Usage:
#   install.sh --profile <m0|dev|gaming|full> [--dry-run] [--yes] [--target DIR]
#
# Profiles (see install/manifests/README.md for exact layer membership):
#   m0       base + desktop + theming + minimal apps  (default, matches the plan's M0)
#   dev      m0 + 40-dev
#   gaming   m0 + 50-gaming
#   full     everything, including 60-flatpak and personal AUR extras
#
# This script only ever touches packages and stows this repo's dotfiles
# into $TARGET (default $HOME). It NEVER touches anything under
# install/system/ — those are gated, separately-invoked changes. See
# docs/ISOLATION.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$REPO_ROOT/install/install.log"
PROFILE="m0"
DRY_RUN=0
ASSUME_YES=0
TARGET="$HOME"

for arg in "$@"; do
    case "$arg" in
        --profile=*) PROFILE="${arg#*=}" ;;
        --profile) shift_next=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --target=*) TARGET="${arg#*=}" ;;
        --help|-h)
            grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
    esac
done
# handle "--profile value" (space-separated) form
args=("$@")
for i in "${!args[@]}"; do
    if [ "${args[$i]}" = "--profile" ] && [ -n "${args[$((i+1))]:-}" ]; then
        PROFILE="${args[$((i+1))]}"
    fi
    if [ "${args[$i]}" = "--target" ] && [ -n "${args[$((i+1))]:-}" ]; then
        TARGET="${args[$((i+1))]}"
    fi
done

export DRY_RUN ASSUME_YES REPO_ROOT LOG_FILE TARGET

# shellcheck source=lib/log.sh
source "$REPO_ROOT/install/lib/log.sh"
# shellcheck source=lib/ui.sh
source "$REPO_ROOT/install/lib/ui.sh"
# shellcheck source=lib/pkg.sh
source "$REPO_ROOT/install/lib/pkg.sh"
# shellcheck source=lib/stow.sh
source "$REPO_ROOT/install/lib/stow.sh"
# shellcheck source=lib/preflight.sh
source "$REPO_ROOT/install/lib/preflight.sh"

: > "$LOG_FILE"
log_info "modern_dotfile installer — profile '$PROFILE', target '$TARGET', dry-run=$DRY_RUN"

case "$PROFILE" in
    m0|dev|gaming|full) ;;
    *) die "unknown profile '$PROFILE' — expected m0|dev|gaming|full" ;;
esac

# ---------------------------------------------------------------------------
# Phase 1 — preflight
# ---------------------------------------------------------------------------
preflight_checks

# ---------------------------------------------------------------------------
# Phase 2 — yay bootstrap
# ---------------------------------------------------------------------------
log_phase "Phase 2/5: yay bootstrap"
bootstrap_yay

# ---------------------------------------------------------------------------
# Phase 3 — package manifests
# ---------------------------------------------------------------------------
log_phase "Phase 3/5: package manifests (profile: $PROFILE)"

MANIFEST_DIR="$REPO_ROOT/install/manifests"
layers=(00-base 10-desktop 20-theming 30-apps)
case "$PROFILE" in
    dev)    layers+=(40-dev) ;;
    gaming) layers+=(50-gaming) ;;
    full)   layers+=(40-dev 50-gaming) ;;
esac

native_pkgs=()
aur_pkgs=()
for layer in "${layers[@]}"; do
    native_file="$MANIFEST_DIR/$layer.txt"
    aur_file="$MANIFEST_DIR/$layer.aur.txt"
    [ -f "$native_file" ] && mapfile -t -O "${#native_pkgs[@]}" native_pkgs < <(parse_manifest "$native_file")
    [ -f "$aur_file" ] && mapfile -t -O "${#aur_pkgs[@]}" aur_pkgs < <(parse_manifest "$aur_file")
done

install_native "${native_pkgs[@]}"
install_aur "${aur_pkgs[@]}"

if [ "$PROFILE" = "full" ]; then
    flatpak_ids=()
    mapfile -t flatpak_ids < <(parse_manifest "$MANIFEST_DIR/60-flatpak.txt")
    install_flatpak "${flatpak_ids[@]}"
fi

# ---------------------------------------------------------------------------
# Phase 4 — stow
# ---------------------------------------------------------------------------
log_phase "Phase 4/5: stow dotfiles -> $TARGET"

stow_packages=(hypr shell theme kitty dolphin gtk qt bash git modern)
for pkg in "${stow_packages[@]}"; do
    stow_package "$pkg" "$TARGET"
done

# devuser's live config.json starts as a copy of the tracked default,
# never overwritten on re-run.
CONFIG_DIR="$TARGET/.config/modern"
if [ ! -f "$CONFIG_DIR/config.json" ] && [ -f "$CONFIG_DIR/config.default.json" ]; then
    run cp "$CONFIG_DIR/config.default.json" "$CONFIG_DIR/config.json"
    log_ok "seeded config.json from config.default.json"
fi

# ---------------------------------------------------------------------------
# Phase 5 — post-install
# ---------------------------------------------------------------------------
log_phase "Phase 5/5: post-install"

run systemctl --user daemon-reload 2>/dev/null || true

if command -v matugen >/dev/null 2>&1; then
    run "$REPO_ROOT/scripts/theme-apply.sh" --initial
else
    log_warn "matugen not found — run scripts/theme-apply.sh manually once it's installed"
fi

log_ok "Install complete for profile '$PROFILE'."
log_info "Next: log in to Hyprland, then read docs/CURSOR-SETUP.md to set up Cursor."
log_info "From your OTHER account, run scripts/check-isolation.sh to confirm nothing leaked."
