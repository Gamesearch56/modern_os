#!/usr/bin/env bash
# Package manifest parsing + install helpers. Source, never execute
# directly. Depends on log.sh and ui.sh being sourced first.

# Strips full-line and trailing '#' comments, blank lines, and whitespace.
# Manifest lines look like "package   # why it's here".
parse_manifest() {
    local file="$1"
    [ -f "$file" ] || return 0
    sed -E 's/#.*$//' "$file" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/\r$//' | grep -v '^$' || true
}

# Reads all manifests matching a glob (e.g. "*.txt" for native, "*.aur.txt"
# for AUR) across the given layer files, deduplicated.
collect_packages() {
    local pattern="$1"; shift
    local files=("$@")
    for f in "${files[@]}"; do
        # $pattern is a glob (*.txt / *.aur.txt), not a literal.
        # shellcheck disable=SC2053
        [[ "$f" == $pattern ]] && parse_manifest "$f"
    done | sort -u
}

bootstrap_yay() {
    if command -v yay >/dev/null 2>&1; then
        log_ok "yay already installed"
        return 0
    fi
    log_info "Bootstrapping yay (AUR helper)..."
    local build_dir
    build_dir="$(mktemp -d)"
    run env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
    # --dir is inside run(), so --dry-run only prints and never cds.
    run makepkg --dir "$build_dir/yay-bin" -si --noconfirm
    rm -rf "$build_dir"
    log_ok "yay installed"
}

install_native() {
    local pkgs=("$@") providers=() rest=() p
    [ ${#pkgs[@]} -eq 0 ] && return 0
    log_info "Installing ${#pkgs[@]} native package(s): ${pkgs[*]}"
    # ffmpeg/mpv depend on virtual `jack`; pipewire-pulse replaces
    # pulseaudio. --noconfirm answers No to "Remove jack2?".
    run sudo pacman -Rdd --noconfirm \
        jack2 jack2-dbus lib32-jack2 \
        pulseaudio pulseaudio-bluetooth pulseaudio-jack \
        pipewire-media-session || true
    for p in "${pkgs[@]}"; do
        case "$p" in
            pipewire|pipewire-alsa|pipewire-jack|pipewire-pulse|wireplumber)
                providers+=("$p") ;;
            *) rest+=("$p") ;;
        esac
    done
    if [ -n "${MODERN_PACMAN_NOSANDBOX:-}" ]; then
        if [ ${#providers[@]} -gt 0 ]; then
            run sudo pacman --disable-sandbox -S --needed --noconfirm "${providers[@]}"
        fi
        [ ${#rest[@]} -eq 0 ] && return 0
        run sudo pacman --disable-sandbox -S --needed --noconfirm "${rest[@]}"
    else
        if [ ${#providers[@]} -gt 0 ]; then
            run sudo pacman -S --needed --noconfirm "${providers[@]}"
        fi
        [ ${#rest[@]} -eq 0 ] && return 0
        run sudo pacman -S --needed --noconfirm "${rest[@]}"
    fi
}

install_aur() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0
    log_info "Installing ${#pkgs[@]} AUR package(s): ${pkgs[*]}"
    run yay -S --needed --noconfirm "${pkgs[@]}"
}

install_flatpak() {
    local ids=("$@")
    [ ${#ids[@]} -eq 0 ] && return 0
    command -v flatpak >/dev/null 2>&1 || { log_warn "flatpak not installed, skipping ${#ids[@]} app(s)"; return 0; }
    log_info "Installing ${#ids[@]} flatpak(s): ${ids[*]}"
    run flatpak install -y --noninteractive flathub "${ids[@]}"
}

# CPU vendor for 00-hw-cpu-*. Override with --cpu.
detect_cpu() {
    local cpu
    cpu="$(awk -F: '/^vendor_id/{gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
    if printf '%s' "$cpu" | grep -qi intel; then
        printf 'intel\n'
        return
    fi
    printf 'amd\n'
}

# GPU class for 00-hw-gpu-*. Override with --hw / --gpu.
detect_gpu() {
    local gpu
    gpu="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA compatible controller|3D controller/{print; exit}')"
    if printf '%s' "$gpu" | grep -qi nvidia; then
        printf 'nvidia\n'
        return
    fi
    if printf '%s' "$gpu" | grep -qi 'intel'; then
        printf 'intel\n'
        return
    fi
    printf 'amd\n'
}

# Turing+ vs Maxwell/Pascal/Volta. Uses lspci chip names, not board names.
detect_nvidia_family() {
    local gpu
    gpu="$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA compatible controller|3D controller/{print; exit}')"
    if printf '%s' "$gpu" | grep -Eqi 'TU1|TU2|GA1|AD1|GB2|GTX 16|RTX'; then
        printf 'nvidia\n'
        return
    fi
    if printf '%s' "$gpu" | grep -Eqi 'GM1|GM2|GP1|GV1|GK|GF'; then
        printf 'nvidia-legacy\n'
        return
    fi
    printf 'nvidia\n'
}

# Legacy single-token helper (cpu-or-gpu). Prefer detect_cpu + detect_gpu.
detect_hw() {
    local gpu
    gpu="$(detect_gpu)"
    if [ "$gpu" = "nvidia" ]; then
        printf 'nvidia\n'
        return
    fi
    detect_cpu
}
