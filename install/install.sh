#!/usr/bin/env bash
# modern_dotfile installer. Idempotent: safe to re-run. Phased, so a
# failure in phase 3 doesn't repeat phases 1-2's work.
#
# Usage:
#   install.sh --profile <m0|dev|gaming|full> [--dry-run] [--yes] [--target DIR]
#              [--allow-live-home]
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
#
# Live-home guard: refuses to stow into /home/bastianweigand (override
# with MODERN_PROTECT_HOME). Pass --allow-live-home only for a deliberate
# cutover onto that account (new-PC install as that username).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$REPO_ROOT/install/install.log"
PROFILE="m0"
DRY_RUN=0
ASSUME_YES=0
ALLOW_LIVE_HOME=0
TARGET="$HOME"

for arg in "$@"; do
    case "$arg" in
        --profile=*) PROFILE="${arg#*=}" ;;
        --profile) shift_next=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --allow-live-home) ALLOW_LIVE_HOME=1 ;;
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

export DRY_RUN ASSUME_YES ALLOW_LIVE_HOME REPO_ROOT LOG_FILE TARGET

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
trap 'rc=$?; log_error "install aborted at line $LINENO (exit $rc). See $LOG_FILE"; exit "$rc"' ERR

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

stow_packages=(hypr shell theme kitty dolphin gtk qt bash git modern systemd xdg fastfetch)
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

if [ "$TARGET" != "$HOME" ]; then
    log_warn "stow target ($TARGET) is not this account's HOME ($HOME)."
    log_warn "  systemctl --user above applies to the user who ran install.sh."
    log_warn "  Enable modern-shell.service after logging in as the target user."
fi

# tokens.json + lock/login assets come from the shipped default wallpaper
# (stow/modern/.../wallpapers/default.jpg) so a first session is not
# unstyled. --no-reload: no Hyprland on this TTY yet. Failure must not
# abort the install — Colors.qml already ships a dark baseline.
default_wp="$TARGET/.config/modern/wallpapers/default.jpg"
wallpaper_state="${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper"
if command -v matugen >/dev/null 2>&1; then
    if [ -f "$wallpaper_state" ]; then
        run "$REPO_ROOT/scripts/theme-apply.sh" --no-reload \
            || log_warn "theme-apply.sh failed — re-run it after Hyprland is up"
    elif [ -f "$default_wp" ]; then
        log_info "applying shipped default wallpaper and generating tokens"
        run "$REPO_ROOT/scripts/theme-apply.sh" --wallpaper "$default_wp" --no-reload \
            || log_warn "theme-apply.sh failed — the shell still starts with the Colors.qml fallback"
        pictures="$HOME/Pictures/Wallpapers"
        run mkdir -p "$pictures"
        if [ ! -e "$pictures/default.jpg" ]; then
            run cp "$default_wp" "$pictures/default.jpg"
        fi
    else
        log_info "no wallpaper set — generating tokens from the fixed-brand seed"
        run "$REPO_ROOT/scripts/theme-apply.sh" --profile fixed-brand --no-reload \
            || log_warn "theme-apply.sh failed — the shell still starts with the Colors.qml fallback"
        log_info "Later: scripts/theme-apply.sh --wallpaper /path/to/image.jpg"
    fi
else
    log_warn "matugen not found — run scripts/theme-apply.sh once it is installed"
fi

log_ok "Install complete for profile '$PROFILE'."
log_info "Start the session with start-hyprland (not Hyprland) — see README.md; a second TTY keeps the daily-driver session."
log_info "From the daily-driver account, run scripts/check-isolation.sh to confirm nothing leaked."
log_info "Log: $LOG_FILE"
