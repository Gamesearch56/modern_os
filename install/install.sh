#!/usr/bin/env bash
# modern_dotfile installer. Idempotent: safe to re-run. Phased, so a
# failure in phase 3 doesn't repeat phases 1-2's work.
#
# Usage:
#   install.sh --profile <m0|gaming|full> [--dry-run] [--yes] [--target DIR]
#              [--allow-live-home] [--dotfiles-only]
#              [--hw amd|intel|nvidia] [--cpu amd|intel]
#              [--extra proton]
#
# --dotfiles-only stows this tree into --target and seeds config/theme.
# Packages and greetd are left alone (already on the machine). Settings
# → Users uses it after useradd so a new account is not a blank Hyprland.
#
# --hw / --gpu selects the GPU stack (mesa/RADV, Intel, or NVIDIA DKMS).
# --cpu selects microcode. Both default to auto-detect so Intel CPU +
# NVIDIA GPU gets intel-ucode *and* the NVIDIA driver. --extra proton
# installs 90-accounts.aur.txt.
# Calamares late: --profile m0 --yes as the new user (never as root).
#
# Profiles (see install/manifests/README.md for exact layer membership):
#   m0       base + desktop + theming + minimal apps  (default)
#   gaming   m0 + 50-gaming
#   full     gaming + 60-flatpak
#
# This script installs packages, stows this repo's dotfiles into $TARGET
# (default $HOME), and enables the greetd login screen on a real user
# home. Plymouth, NVIDIA initramfs, snapper, and modern-usersd stay
# under install/system/ for ISO provision — see docs/ISOLATION.md.
#
# Live-home guard: if MODERN_PROTECT_HOME is set, refuses to stow there
# unless --allow-live-home is passed. See docs/ISOLATION.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$REPO_ROOT/install/install.log"
PROFILE="m0"
HW="auto"
CPU="auto"
EXTRA=""
DRY_RUN=0
ASSUME_YES=0
ALLOW_LIVE_HOME=0
DOTFILES_ONLY=0
TARGET="$HOME"
SESSION_HOME="$HOME"

for arg in "$@"; do
    case "$arg" in
        --profile=*) PROFILE="${arg#*=}" ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --allow-live-home) ALLOW_LIVE_HOME=1 ;;
        --dotfiles-only) DOTFILES_ONLY=1 ;;
        --hw=*) HW="${arg#*=}" ;;
        --gpu=*) HW="${arg#*=}" ;;
        --cpu=*) CPU="${arg#*=}" ;;
        --extra=*) EXTRA="${arg#*=}" ;;
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
    if [ "${args[$i]}" = "--hw" ] && [ -n "${args[$((i+1))]:-}" ]; then
        HW="${args[$((i+1))]}"
    fi
    if [ "${args[$i]}" = "--gpu" ] && [ -n "${args[$((i+1))]:-}" ]; then
        HW="${args[$((i+1))]}"
    fi
    if [ "${args[$i]}" = "--cpu" ] && [ -n "${args[$((i+1))]:-}" ]; then
        CPU="${args[$((i+1))]}"
    fi
    if [ "${args[$i]}" = "--extra" ] && [ -n "${args[$((i+1))]:-}" ]; then
        EXTRA="${args[$((i+1))]}"
    fi
done

export DRY_RUN ASSUME_YES ALLOW_LIVE_HOME DOTFILES_ONLY REPO_ROOT LOG_FILE TARGET

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
# shellcheck source=lib/greetd.sh
source "$REPO_ROOT/install/lib/greetd.sh"

: > "$LOG_FILE"
_err_trap() {
    local rc=$?
    log_error "install aborted at line ${1:-?} (exit $rc). See $LOG_FILE"
    exit "$rc"
}
trap '_err_trap $LINENO' ERR

log_info "modern_dotfile installer — profile '$PROFILE', gpu='$HW', cpu='$CPU', extra='$EXTRA', target '$TARGET', dry-run=$DRY_RUN, dotfiles-only=$DOTFILES_ONLY"

case "$PROFILE" in
    m0|gaming|full) ;;
    *) die "unknown profile '$PROFILE' — expected m0|gaming|full" ;;
esac

case "$CPU" in
    auto) CPU="$(detect_cpu)"; log_info "detected CPU vendor: $CPU" ;;
    amd|intel) ;;
    *) die "unknown --cpu '$CPU' — expected auto|amd|intel" ;;
esac

case "$HW" in
    auto) HW="$(detect_gpu)"; log_info "detected GPU class: $HW" ;;
    amd|intel|nvidia) ;;
    *) die "unknown --hw '$HW' — expected auto|amd|intel|nvidia" ;;
esac

GPU_FAMILY="$HW"
if [ "$HW" = "nvidia" ]; then
    GPU_FAMILY="$(detect_nvidia_family)"
    log_info "NVIDIA driver family: $GPU_FAMILY"
fi

case "$EXTRA" in
    ""|proton) ;;
    *) die "unknown --extra '$EXTRA' — expected proton or omit" ;;
esac

# ---------------------------------------------------------------------------
# Phase 1 — preflight
# ---------------------------------------------------------------------------
preflight_checks

# ---------------------------------------------------------------------------
# Phase 2 — yay bootstrap
# ---------------------------------------------------------------------------
if [ "$DOTFILES_ONLY" -eq 1 ]; then
    log_info "dotfiles-only: skipping yay and package manifests"
else
log_phase "Phase 2/5: yay bootstrap"
if [ -n "${MODERN_ROOT_PLAN:-}" ] && ! command -v yay >/dev/null 2>&1; then
    # makepkg -si needs sudo, which a terminal-less update cannot answer.
    log_warn "yay missing — skipping AUR until 'modern update' runs in a terminal"
    MODERN_SKIP_AUR=1
else
    bootstrap_yay
fi

# ---------------------------------------------------------------------------
# Phase 3 — package manifests
# ---------------------------------------------------------------------------
log_phase "Phase 3/5: package manifests (profile: $PROFILE)"

MANIFEST_DIR="$REPO_ROOT/install/manifests"
layers=(00-base 10-desktop 20-theming 30-apps)
case "$PROFILE" in
    gaming|full) layers+=(50-gaming) ;;
esac

native_pkgs=()
aur_pkgs=()
for layer in "${layers[@]}"; do
    native_file="$MANIFEST_DIR/$layer.txt"
    aur_file="$MANIFEST_DIR/$layer.aur.txt"
    [ -f "$native_file" ] && mapfile -t -O "${#native_pkgs[@]}" native_pkgs < <(parse_manifest "$native_file")
    [ -f "$aur_file" ] && mapfile -t -O "${#aur_pkgs[@]}" aur_pkgs < <(parse_manifest "$aur_file")
done

hw_cpu="$MANIFEST_DIR/00-hw-cpu-${CPU}.txt"
if [ -f "$hw_cpu" ]; then
    mapfile -t -O "${#native_pkgs[@]}" native_pkgs < <(parse_manifest "$hw_cpu")
fi
hw_gpu="$MANIFEST_DIR/00-hw-gpu-${GPU_FAMILY}.txt"
if [ -f "$hw_gpu" ]; then
    mapfile -t -O "${#native_pkgs[@]}" native_pkgs < <(parse_manifest "$hw_gpu")
fi
if detect_wifi_wl; then
    log_info "Broadcom wifi needs the wl driver"
    mapfile -t -O "${#native_pkgs[@]}" native_pkgs < <(parse_manifest "$MANIFEST_DIR/00-hw-wifi-broadcom-wl.txt")
fi
if [ "$PROFILE" = "gaming" ] || [ "$PROFILE" = "full" ]; then
    # GPU_FAMILY, not HW: 50-hw-nvidia's lib32-nvidia-utils would pull
    # nvidia-utils onto a nouveau (nvidia-legacy) machine.
    hw_game="$MANIFEST_DIR/50-hw-${GPU_FAMILY}.txt"
    if [ -f "$hw_game" ]; then
        mapfile -t -O "${#native_pkgs[@]}" native_pkgs < <(parse_manifest "$hw_game")
    fi
fi
if [ "$EXTRA" = "proton" ]; then
    mapfile -t -O "${#aur_pkgs[@]}" aur_pkgs < <(parse_manifest "$MANIFEST_DIR/90-accounts.aur.txt")
fi

install_native "${native_pkgs[@]}"
install_aur "${aur_pkgs[@]}"

if [ "$PROFILE" = "full" ]; then
    flatpak_ids=()
    mapfile -t flatpak_ids < <(parse_manifest "$MANIFEST_DIR/60-flatpak.txt")
    install_flatpak "${flatpak_ids[@]}"
fi
fi

# ---------------------------------------------------------------------------
# Phase 4 — stow
# ---------------------------------------------------------------------------
log_phase "Phase 4/5: stow dotfiles -> $TARGET"

stow_packages=(hypr shell theme kitty gtk qt bash git modern systemd xdg fontconfig fastfetch mpv imv pipewire)
for pkg in "${stow_packages[@]}"; do
    stow_package "$pkg" "$TARGET"
done

# The target user's live config.json starts as a copy of the tracked default,
# never overwritten on re-run.
CONFIG_DIR="$TARGET/.config/modern"
if [ ! -f "$CONFIG_DIR/config.json" ] && [ -f "$CONFIG_DIR/config.default.json" ]; then
    run cp "$CONFIG_DIR/config.default.json" "$CONFIG_DIR/config.json"
    log_ok "seeded config.json from config.default.json"
fi

# Hyprland/Quickshell/scripts exec this clone. ISO Calamares still clones
# to $HOME/modern_dotfile; a Cursor tree elsewhere needs this pointer.
if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log_info "would write $CONFIG_DIR/repo -> $REPO_ROOT"
else
    run mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$REPO_ROOT" >"$CONFIG_DIR/repo"
    log_ok "wrote $CONFIG_DIR/repo"
fi

# ---------------------------------------------------------------------------
# Phase 5 — post-install
# ---------------------------------------------------------------------------
log_phase "Phase 5/5: post-install"

# When --target is another home, theme-apply and nautilus-prefs must write
# there — they read $HOME / XDG_*, not TARGET.
theme_env=()
if [ "$TARGET" != "$HOME" ]; then
    theme_env=(
        env
        "HOME=$TARGET"
        "XDG_CONFIG_HOME=$TARGET/.config"
        "XDG_STATE_HOME=$TARGET/.local/state"
        "XDG_DATA_HOME=$TARGET/.local/share"
    )
    log_warn "stow target ($TARGET) is not this account's HOME ($HOME)."
    log_warn "  systemctl --user below applies to the user who ran install.sh."
    log_warn "  Theme files are written under the target home."
fi

STATE_DIR="${XDG_STATE_HOME:-$TARGET/.local/state}/modern"
if [ "$TARGET" != "$HOME" ]; then
    STATE_DIR="$TARGET/.local/state/modern"
fi
run mkdir -p "$STATE_DIR"
if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log_info "would write $STATE_DIR/hw.json gpu=$HW cpu=$CPU"
else
    printf '{"gpu":"%s","cpu":"%s"}\n' "$HW" "$CPU" >"$STATE_DIR/hw.json"
    log_ok "wrote $STATE_DIR/hw.json"
fi

# A Settings update already has a running shell. Rewriting tokens,
# config.json, or user units here restarts that shell and kills this
# installer mid-stow. reload-ui.sh applies the new tree once, after.
if [ "${MODERN_LIVE_UPDATE:-}" = 1 ]; then
    log_info "live session update — leaving theme and user services alone"
else
if [ -S "${XDG_RUNTIME_DIR:-}/bus" ]; then
    run systemctl --user daemon-reload 2>/dev/null || true
else
    log_info "no user session bus — skip daemon-reload"
fi

# tokens.json + lock/login assets come from the shipped default wallpaper
# (stow/modern/.../wallpapers/default.jpg) so a first session is not
# unstyled. --no-reload: no Hyprland on this TTY yet. Failure must not
# abort the install — Colors.qml already ships a dark baseline.
# The rest of that directory is the preinstalled picker library; seed
# missing names into XDG Pictures/Wallpapers and never overwrite user files.
# Stock capture paths in config.json follow the same locale folders.
run env HOME="$TARGET" \
    XDG_CONFIG_HOME="$TARGET/.config" \
    XDG_STATE_HOME="$TARGET/.local/state" \
    XDG_DATA_HOME="$TARGET/.local/share" \
    "$REPO_ROOT/scripts/xdg-capture-seed.sh" "$CONFIG_DIR/config.json" \
    || log_warn "xdg-capture-seed.sh skipped — capture folders stay at the config.json defaults"
shipped_wp_dir="$TARGET/.config/modern/wallpapers"
default_wp="$shipped_wp_dir/default.jpg"
pictures="$(
    export HOME="$TARGET"
    export XDG_CONFIG_HOME="$TARGET/.config"
    # shellcheck source=../scripts/lib/paths.sh
    source "$REPO_ROOT/scripts/lib/paths.sh"
    xdg_wallpapers_dir
)"
if [ -d "$shipped_wp_dir" ]; then
    run mkdir -p "$pictures"
    for f in "$shipped_wp_dir"/*; do
        [ -f "$f" ] || continue
        case "${f,,}" in
            *.jpg|*.jpeg|*.png|*.webp) ;;
            *) continue ;;
        esac
        dest="$pictures/$(basename "$f")"
        if [ ! -e "$dest" ]; then
            run cp "$f" "$dest"
        fi
    done
fi
# The picker lists the library copy and hides the shipped symlink of
# the same name. Remember the library file so the tile is selected
# and the first session can read it.
if [ -f "$pictures/default.jpg" ]; then
    default_wp="$pictures/default.jpg"
fi
wallpaper_state="$STATE_DIR/current-wallpaper"
if command -v matugen >/dev/null 2>&1; then
    if [ -f "$wallpaper_state" ]; then
        run "${theme_env[@]}" "$REPO_ROOT/scripts/theme-apply.sh" --no-reload \
            || log_warn "theme-apply.sh failed — re-run it after Hyprland is up"
    elif [ -f "$default_wp" ]; then
        log_info "applying shipped default wallpaper and generating tokens"
        run "${theme_env[@]}" "$REPO_ROOT/scripts/theme-apply.sh" --wallpaper "$default_wp" --no-reload \
            || log_warn "theme-apply.sh failed — the shell still starts with the Colors.qml fallback"
    else
        log_info "no wallpaper set — generating tokens from the fixed-brand seed"
        run "${theme_env[@]}" "$REPO_ROOT/scripts/theme-apply.sh" --profile fixed-brand --no-reload \
            || log_warn "theme-apply.sh failed — the shell still starts with the Colors.qml fallback"
        log_info "Later: scripts/theme-apply.sh --wallpaper /path/to/image.jpg"
    fi
else
    log_warn "matugen not found — run scripts/theme-apply.sh once it is installed"
fi
fi

# Nautilus / xdg-open follow Settings → Applications video/image/text/folder defaults.
run "$REPO_ROOT/scripts/mime-defaults.sh" \
    --config "$TARGET/.config/modern/config.json" \
    --mimeapps "$TARGET/.config/mimeapps.list" \
    || log_warn "mime-defaults.sh failed — set video/image/text/folder defaults in Settings → Applications"
if [ "$DOTFILES_ONLY" -eq 1 ]; then
    log_info "dotfiles-only: skipping nautilus-prefs (gsettings needs a session)"
else
    run "${theme_env[@]}" "$REPO_ROOT/scripts/nautilus-prefs.sh" \
        || log_warn "nautilus-prefs.sh skipped — Nautilus schemas not installed yet"
fi

# Patched Phylax Confirms as $USER and keeps Authenticating off the error
# color. Cargo rebuilds it; machines without cargo get the prebuilt.
# Restart afterwards — a running agent keeps the previous binary mapped.
if [ "$DOTFILES_ONLY" -eq 1 ]; then
    log_info "dotfiles-only: skipping Phylax rebuild"
else
    if command -v cargo >/dev/null 2>&1; then
        run "${theme_env[@]}" "$REPO_ROOT/scripts/build-phylax.sh" \
            || log_warn "build-phylax.sh failed — installing the prebuilt agent"
    else
        log_warn "cargo missing — installing the prebuilt Phylax agent"
    fi
    if [ "$DRY_RUN" -eq 0 ]; then
        phylax_dest="$TARGET/.local/bin/phylax"
        phylax_prebuilt="$REPO_ROOT/install/prebuilt/phylax"
        if ! { [ -f "$phylax_dest" ] && grep -a -F -q 'auth-progress' "$phylax_dest"; }; then
            if [ -f "$phylax_prebuilt" ]; then
                mkdir -p "$(dirname "$phylax_dest")"
                install -m 755 "$phylax_prebuilt" "$phylax_dest" \
                    || log_warn "prebuilt phylax missing — Authenticating stays on the error color"
            else
                log_warn "prebuilt phylax missing — Authenticating stays on the error color"
            fi
        fi
        if [ "$TARGET" = "$SESSION_HOME" ]; then
            systemctl --user try-restart phylax.service >/dev/null 2>&1 || true
        fi
    fi
fi

# kitty.conf globincludes colors.conf; fallbacks in kitty.conf keep
# SUPER+T working until theme-apply writes the live file.

if [ "$DOTFILES_ONLY" -eq 1 ]; then
    log_info "skipping greetd (dotfiles-only)"
elif greetd_target_is_live_user "$TARGET" && [ -n "${MODERN_ROOT_PLAN:-}" ] && [ "$DRY_RUN" -eq 0 ]; then
    printf 'greetd\n' >>"$MODERN_ROOT_PLAN"
    log_info "greetd deferred to the update's root step"
elif greetd_target_is_live_user "$TARGET"; then
    greetd_apply "$(greetd_user_for_home "$TARGET")"
else
    log_info "skipping greetd (target '$TARGET' is not a login home)"
fi

log_ok "Install complete for profile '$PROFILE'."
log_info "Reboot to the login screen, then start-hyprland is launched by greetd — see README.md."
log_info "Log: $LOG_FILE"
