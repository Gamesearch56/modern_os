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
    run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
    (cd "$build_dir/yay-bin" && run makepkg -si --noconfirm)
    rm -rf "$build_dir"
    log_ok "yay installed"
}

install_native() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0
    log_info "Installing ${#pkgs[@]} native package(s): ${pkgs[*]}"
    run sudo pacman -S --needed --noconfirm "${pkgs[@]}"
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
