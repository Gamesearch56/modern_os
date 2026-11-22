#!/usr/bin/env bash
# ModernOS's own pacman packages (install/packages/*) for the ISO local
# repo. The live squashfs installs them and unpackfs copies that system
# onto the disk, so a fresh install has them even when the repo pin
# Calamares clones predates a package. Source after iso-aur-repo.sh;
# iso_attach_aur_repo calls this with the builder user set up. ROOT and
# log come from iso-build.sh.
# shellcheck disable=SC2154

iso_local_packages() {
    local repo="$1" build="$2" profile="$3" dir name src
    for dir in "$ROOT"/install/packages/*/; do
        [ -f "$dir/PKGBUILD" ] || continue
        name="$(basename "$dir")"
        src="$build/local-$name"
        rm -rf "$src"
        cp -a "$dir" "$src"
        chown -R "$ISO_AUR_BUILDER:$ISO_AUR_BUILDER" "$src"
        log "building $name for the ISO local repo"
        iso_aur_makepkg "$src" force
        find "$src" -maxdepth 1 -name '*.pkg.tar.*' ! -name '*.sig' -exec cp -a {} "$repo/" \;
        if [ -f "$profile/packages.x86_64" ] && ! grep -qxF "$name" "$profile/packages.x86_64"; then
            printf '%s\n' "$name" >>"$profile/packages.x86_64"
        fi
    done
}
