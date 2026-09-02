#!/usr/bin/env bash
# Build AUR packages into a file:// repo for mkarchiso. Source from
# iso-build.sh after PROFILE_WORK exists. ROOT, WORK, die, and log
# come from the caller.
#
# Live homes are 0700, so modernisoaur cannot mkdir under iso/out/.
# Bind-mount $WORK/aur onto /tmp so the builder writes a traversable
# path while packages stay on the ISO output disk. User + sudoers +
# mount are removed on EXIT.
# shellcheck disable=SC2154

ISO_AUR_BUILDER=modernisoaur
ISO_AUR_MNT=""

iso_sanitize_package_list() {
    local src="$1"
    local tmp line
    local -A seen=()
    [ -f "$src" ] || return 0
    tmp="$(mktemp)"
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -n "$line" ] || continue
        [ -n "${seen[$line]:-}" ] && continue
        seen[$line]=1
        printf '%s\n' "$line"
    done <"$src" >"$tmp"
    mv "$tmp" "$src"
}

iso_aur_cleanup() {
    if [ -n "${ISO_AUR_MNT:-}" ]; then
        if mountpoint -q "$ISO_AUR_MNT"; then
            umount "$ISO_AUR_MNT" >/dev/null 2>&1 || umount -l "$ISO_AUR_MNT" >/dev/null 2>&1 || true
        fi
        rmdir "$ISO_AUR_MNT" >/dev/null 2>&1 || true
        ISO_AUR_MNT=""
    fi
    rm -f "/etc/sudoers.d/${ISO_AUR_BUILDER}"
    if id "$ISO_AUR_BUILDER" >/dev/null 2>&1; then
        pkill -u "$ISO_AUR_BUILDER" >/dev/null 2>&1 || true
        userdel "$ISO_AUR_BUILDER" >/dev/null 2>&1 || true
    fi
}

iso_calamares_limit_languages() {
    local src="$1"
    local hook="$ROOT/iso/releng/calamares-limit-languages.py"
    [ -f "$hook" ] || die "missing $hook"
    install -m 0644 "$hook" "$src/calamares-limit-languages.py"
    chown "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" "$src/calamares-limit-languages.py"
    if ! grep -F 'calamares-limit-languages.py' "$src/PKGBUILD" >/dev/null; then
        cat >>"$src/PKGBUILD" <<'EOF'

prepare() {
  python3 "$startdir/calamares-limit-languages.py" \
    "$srcdir/$_pkgname-$pkgver/src/libcalamares/locale/TranslationsModel.cpp"
}
EOF
        chown "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" "$src/PKGBUILD"
    fi
}

# mkarchiso does s/#.*// and keeps leftover spaces as the package name.
iso_attach_aur_repo() {
    local profile="$1"
    local list="$ROOT/iso/releng/packages.aur.x86_64"
    local store repo build home
    local pkg line src dest
    [ -f "$list" ] || return 0
    [ "$(id -u)" -eq 0 ] || die "AUR repo build needs root (same as mkarchiso)"

    iso_aur_cleanup

    store="$WORK/aur"
    mkdir -p "$store/repo" "$store/build" "$store/home"
    ISO_AUR_MNT="$(mktemp -d /tmp/modern-iso-aur.XXXXXX)"
    mount --bind "$store" "$ISO_AUR_MNT"
    repo="$ISO_AUR_MNT/repo"
    build="$ISO_AUR_MNT/build"
    home="$ISO_AUR_MNT/home"

    command -v repo-add >/dev/null 2>&1 || pacman -S --needed --noconfirm pacman-contrib
    pacman -S --needed --noconfirm base-devel git sudo

    useradd -M -d "$home" -s /usr/bin/nologin "$ISO_AUR_BUILDER"
    printf '%s ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' "$ISO_AUR_BUILDER" \
        >"/etc/sudoers.d/${ISO_AUR_BUILDER}"
    chmod 0440 "/etc/sudoers.d/${ISO_AUR_BUILDER}"
    chown -R "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" "$store"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        pkg="${line//[[:space:]]/}"
        [ -n "$pkg" ] || continue
        src="$build/$pkg"
        dest="https://aur.archlinux.org/${pkg}.git"
        log "building AUR $pkg for the ISO local repo"
        if [ ! -d "$src/.git" ]; then
            sudo -u "$ISO_AUR_BUILDER" git clone --depth 1 "$dest" "$src"
        fi
        if [ "$pkg" = calamares ]; then
            iso_calamares_limit_languages "$src"
            sudo -u "$ISO_AUR_BUILDER" makepkg --dir "$src" -sf --noconfirm
        else
            sudo -u "$ISO_AUR_BUILDER" makepkg --dir "$src" -s --noconfirm
        fi
        find "$src" -maxdepth 1 -name '*.pkg.tar.*' ! -name '*.sig' \
            -exec cp -a {} "$repo/" \;
        if [ -f "$profile/packages.x86_64" ] && ! grep -qxF "$pkg" "$profile/packages.x86_64"; then
            printf '%s\n' "$pkg" >>"$profile/packages.x86_64"
        fi
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
