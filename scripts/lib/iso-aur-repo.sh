#!/usr/bin/env bash
# Build AUR packages into a file:// repo for mkarchiso. Source from
# iso-build.sh after PROFILE_WORK exists. ROOT, WORK, die, and log
# come from the caller.
# shellcheck disable=SC2154

iso_attach_aur_repo() {
    local profile="$1"
    local list="$ROOT/iso/releng/packages.aur.x86_64"
    local repo="$WORK/aur-repo"
    local build="$WORK/aur-build"
    local builder="isoaur"
    local pkg line src dest
    [ -f "$list" ] || return 0
    [ "$(id -u)" -eq 0 ] || die "AUR repo build needs root (same as mkarchiso)"

    mkdir -p "$repo" "$build"
    command -v repo-add >/dev/null 2>&1 || pacman -S --needed --noconfirm pacman-contrib
    pacman -S --needed --noconfirm base-devel git sudo

    if ! id "$builder" >/dev/null 2>&1; then
        useradd -m -d "$WORK/isoaur-home" "$builder"
    fi
    printf '%s ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' "$builder" \
        >"/etc/sudoers.d/$builder"
    chmod 0440 "/etc/sudoers.d/$builder"
    chown -R "$builder:$builder" "$build"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        pkg="${line//[[:space:]]/}"
        [ -n "$pkg" ] || continue
        src="$build/$pkg"
        dest="https://aur.archlinux.org/${pkg}.git"
        log "building AUR $pkg for the ISO local repo"
        sudo -u "$builder" git clone --depth 1 "$dest" "$src"
        sudo -u "$builder" makepkg --dir "$src" -s --noconfirm
        find "$src" -maxdepth 1 -name '*.pkg.tar.*' ! -name '*.sig' \
            -exec cp -a {} "$repo/" \;
    done <"$list"

    shopt -s nullglob
    local pkgs=("$repo"/*.pkg.tar.*)
    shopt -u nullglob
    [ ${#pkgs[@]} -gt 0 ] || die "no AUR packages built from $list"
    repo-add "$repo/modern-iso.db.tar.gz" "${pkgs[@]}"
    printf '\n[modern-iso]\nSigLevel = Optional TrustAll\nServer = file://%s\n' \
        "$repo" >>"$profile/pacman.conf"
    log "AUR repo attached at $repo"
}
