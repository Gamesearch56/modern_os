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

# The builder cannot walk the caller's cwd when that is under a 0700
# home. git-remote-https discovers a repo from cwd and aborts with
# "Invalid path … Permission denied" before the clone writes anything.
# sudo's -D directory option is refused by sudoers for this command.
# The German message names that option -C. cd to /tmp as root first so the
# inherited cwd is one the builder may keep, then cd to the work dir.
iso_aur_run() {
    local dir="$1"
    shift
    (
        cd /tmp || exit
        sudo -u "$ISO_AUR_BUILDER" \
            /bin/bash -c 'cd "$1" && shift && exec "$@"' bash "$dir" "$@"
    )
}

iso_aur_ensure_rustup() {
    # Host rustup provides cargo/rustc shims. modernisoaur has an empty
    # ~/.rustup, so phylax-git (makedepend cargo) dies in the same way
    # source matugen did. Skip when rustup is absent (makepkg -s can
    # install extra/rust instead).
    local home="${ISO_AUR_HOME:-/tmp}"
    command -v rustup >/dev/null 2>&1 || return 0
    if iso_aur_run "$home" rustc --version >/dev/null 2>&1; then
        return 0
    fi
    log "rustup default stable for $ISO_AUR_BUILDER (host has rustup, no toolchain)"
    iso_aur_run "$home" rustup default stable \
        || die "rustup default stable failed for $ISO_AUR_BUILDER"
}

iso_calamares_limit_languages() {
    local src="$1"
    local hook="$ROOT/iso/releng/calamares-limit-languages.py"
    local locales="${ISO_INSTALLER_LOCALES:-}"
    local net="$ROOT/iso/releng/calamares-modernnet"
    local apps="$ROOT/iso/releng/calamares-modernapps"
    [ -f "$hook" ] || die "missing $hook"
    [ -n "$locales" ] && [ -f "$locales" ] \
        || die "ISO_INSTALLER_LOCALES unset or missing (iso-build.sh generates it)"
    [ -d "$net" ] || die "missing $net"
    [ -d "$apps" ] || die "missing $apps"
    install -m 0644 "$hook" "$src/calamares-limit-languages.py"
    install -m 0644 "$locales" "$src/installer-locales.json"
    rm -rf "$src/calamares-modernnet" "$src/calamares-modernapps"
    cp -a "$net" "$src/calamares-modernnet"
    cp -a "$apps" "$src/calamares-modernapps"
    chown "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" \
        "$src/calamares-limit-languages.py" "$src/installer-locales.json"
    chown -R "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" \
        "$src/calamares-modernnet" "$src/calamares-modernapps"
    if ! grep -F 'calamares-limit-languages.py' "$src/PKGBUILD" >/dev/null; then
        cat >>"$src/PKGBUILD" <<'EOF'

prepare() {
  python3 "$startdir/calamares-limit-languages.py" \
    "$srcdir/$_pkgname-$pkgver"
}
EOF
        chown "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" "$src/PKGBUILD"
    fi
}

iso_aur_pkg_stamp() {
    local src="$1" pkg="$2"
    # The network page is copied into the Calamares tree before the
    # build. Hashing only the PKGBUILD reused an older module, so the
    # ISO's Refresh button never waited for a scan.
    if [ "$pkg" = calamares ]; then
        {
            cat "$src/PKGBUILD" \
                "$ROOT/iso/releng/calamares-limit-languages.py" \
                "${ISO_INSTALLER_LOCALES:?iso-build.sh generates it}"
            find "$ROOT/iso/releng/calamares-modernnet" \
                "$ROOT/iso/releng/calamares-modernapps" -type f -print0 \
                | sort -z \
                | xargs -0 -r cat
        } | sha256sum | awk '{print $1}'
    else
        sha256sum "$src/PKGBUILD" | awk '{print $1}'
    fi
}

iso_aur_cache_hit() {
    local cached="$1" repo="$2"
    local f found=0
    [ -d "$cached" ] || return 1
    shopt -s nullglob
    local pkgs=("$cached"/*.pkg.tar.*)
    shopt -u nullglob
    [ ${#pkgs[@]} -gt 0 ] || return 1
    for f in "${pkgs[@]}"; do
        case "$f" in
            *.sig) continue ;;
        esac
        cp -a "$f" "$repo/"
        found=1
    done
    [ "$found" -eq 1 ]
}

iso_aur_makepkg() {
    local src="$1" force="$2"
    local jobs
    jobs="$(nproc 2>/dev/null || echo 1)"
    if [ "$force" = force ]; then
        iso_aur_run "$src" \
            env MAKEFLAGS="-j${jobs}" CMAKE_BUILD_PARALLEL_LEVEL="$jobs" \
            makepkg --dir "$src" -sf --noconfirm
    else
        iso_aur_run "$src" \
            env MAKEFLAGS="-j${jobs}" CMAKE_BUILD_PARALLEL_LEVEL="$jobs" \
            makepkg --dir "$src" -s --noconfirm
    fi
}

# mkarchiso does s/#.*// and keeps leftover spaces as the package name.
iso_attach_aur_repo() {
    local profile="$1"
    local list="$ROOT/iso/releng/packages.aur.x86_64"
    local store repo build home cache
    local pkg line src dest stamp cached
    [ -f "$list" ] || return 0
    [ "$(id -u)" -eq 0 ] || die "AUR repo build needs root (same as mkarchiso)"

    iso_aur_cleanup

    store="$WORK/aur"
    cache="${MODERN_ISO_AUR_CACHE:-$WORK/../aur-cache}"
    mkdir -p "$store/repo" "$store/build" "$store/home" "$cache"
    ISO_AUR_MNT="$(mktemp -d /tmp/modern-iso-aur.XXXXXX)"
    mount --bind "$store" "$ISO_AUR_MNT"
    repo="$ISO_AUR_MNT/repo"
    build="$ISO_AUR_MNT/build"
    home="$ISO_AUR_MNT/home"
    ISO_AUR_HOME="$home"

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
            iso_aur_run "$build" git clone --depth 1 "$dest" "$src"
        fi
        if [ "$pkg" = calamares ]; then
            iso_calamares_limit_languages "$src"
        fi
        stamp="$(iso_aur_pkg_stamp "$src" "$pkg")"
        cached="$cache/$pkg/$stamp"
        if iso_aur_cache_hit "$cached" "$repo"; then
            log "AUR $pkg cache hit"
        else
            if grep -qE '\bcargo\b' "$src/PKGBUILD" 2>/dev/null; then
                iso_aur_ensure_rustup
            fi
            if [ "$pkg" = calamares ]; then
                iso_aur_makepkg "$src" force
            else
                iso_aur_makepkg "$src" ""
            fi
            find "$src" -maxdepth 1 -name '*.pkg.tar.*' ! -name '*.sig' \
                -exec cp -a {} "$repo/" \;
            mkdir -p "$cached"
            find "$src" -maxdepth 1 -name '*.pkg.tar.*' ! -name '*.sig' \
                -exec cp -a {} "$cached/" \;
        fi
        if [ -f "$profile/packages.x86_64" ] && ! grep -qxF "$pkg" "$profile/packages.x86_64"; then
            printf '%s\n' "$pkg" >>"$profile/packages.x86_64"
        fi
    done <"$list"
    iso_local_packages "$repo" "$build" "$profile"

    shopt -s nullglob
    local pkgs=("$repo"/*.pkg.tar.*)
    shopt -u nullglob
    [ ${#pkgs[@]} -gt 0 ] || die "no AUR packages built from $list"
    repo-add "$repo/modern-iso.db.tar.gz" "${pkgs[@]}"
    printf '\n[modern-iso]\nSigLevel = Optional TrustAll\nServer = file://%s\n' \
        "$repo" >>"$profile/pacman.conf"
    # The host package cache keeps the previous file when the name did
    # not change. pacman then calls it corrupt and, with no one to answer
    # "delete it?", the image build stops.
    iso_drop_stale_pkg_cache "$repo"
    log "AUR repo attached at $repo"
}

# Replace a cached package that is not the file this repo just built.
# Same filename, different bytes: the database checksum no longer matches.
iso_drop_stale_pkg_cache() {
    local repo="$1" cache f base
    cache="${ISO_PKG_CACHE:-}"
    if [ -z "$cache" ]; then
        cache="$(pacman-conf CacheDir 2>/dev/null | head -n1 || true)"
    fi
    [ -n "$cache" ] && [ -d "$cache" ] || return 0
    shopt -s nullglob
    for f in "$repo"/*.pkg.tar.*; do
        case "$f" in
            *.sig) continue ;;
        esac
        base="$(basename "$f")"
        [ -f "$cache/$base" ] || continue
        cmp -s "$f" "$cache/$base" && continue
        log "replacing stale cached package $base"
        cp -a "$f" "$cache/$base"
        rm -f "$cache/$base.sig"
    done
    shopt -u nullglob
}
