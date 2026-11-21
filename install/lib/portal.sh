#!/usr/bin/env bash
# Registers ModernOS Files as other apps' file chooser. xdg-desktop-portal
# only reads backends from /usr/share/xdg-desktop-portal/portals, so the
# registration is the modern-portal pacman package (install/packages)
# rather than a file copied into /usr/share. Source, never execute
# directly. Depends on log.sh and ui.sh being sourced first.

PORTAL_PKG=modern-portal

portal_version() {
    local dir="$REPO_ROOT/install/packages/$PORTAL_PKG" ver rel
    ver="$(sed -n 's/^pkgver=//p' "$dir/PKGBUILD")"
    rel="$(sed -n 's/^pkgrel=//p' "$dir/PKGBUILD")"
    printf '%s-%s\n' "$ver" "$rel"
}

# makepkg in a scratch copy so the checkout never gains src/ or pkg/.
# Prints the built package path.
portal_build() {
    local out="$1" dir="$REPO_ROOT/install/packages/$PORTAL_PKG" work file
    work="$(mktemp -d)"
    cp -- "$dir/PKGBUILD" "$dir/modern.portal" "$work/"
    mkdir -p "$out"
    if ! (cd "$work" && PKGDEST="$out" SRCDEST="$work" BUILDDIR="$work/build" PKGEXT=.pkg.tar.zst \
        makepkg -f --nodeps --noconfirm >"$work/makepkg.log" 2>&1); then
        cat "$work/makepkg.log" >&2
        rm -rf "$work"
        return 1
    fi
    rm -rf "$work"
    file="$out/$PORTAL_PKG-$(portal_version)-any.pkg.tar.zst"
    [ -f "$file" ] || return 1
    printf '%s\n' "$file"
}

# Settings → Update has no sudo. The package is built here, as the user,
# under a fixed name in the state dir; the update's root step installs
# only that file (scripts/lib/root-plan.sh root_plan_portal_pkg).
portal_apply() {
    local want have tmp file state
    want="$(portal_version)"
    have="$(pacman -Q "$PORTAL_PKG" 2>/dev/null | awk '{ print $2 }' || true)"
    if [ "$have" = "$want" ]; then
        log_ok "file chooser portal already installed ($want)"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "file chooser portal: would build and install $PORTAL_PKG $want"
        return 0
    fi
    if [ "$(id -u)" -eq 0 ]; then
        log_warn "file chooser portal: makepkg cannot run as root; the next install as the user adds it"
        return 0
    fi
    if [ -n "${MODERN_ROOT_PLAN:-}" ]; then
        state="$TARGET/.local/state/modern/packages"
        file="$(portal_build "$state")" || { log_warn "file chooser portal was not built"; return 0; }
        mv -f -- "$file" "$state/$PORTAL_PKG.pkg.tar.zst"
        printf 'portal\n' >>"$MODERN_ROOT_PLAN"
        log_info "file chooser portal deferred to the update's root step"
        return 0
    fi
    tmp="$(mktemp -d)"
    if file="$(portal_build "$tmp")" && sudo pacman -U --noconfirm --needed "$file"; then
        log_ok "file chooser portal installed ($want)"
        systemctl --user try-restart xdg-desktop-portal.service >/dev/null 2>&1 || true
    else
        log_warn "file chooser portal was not installed; apps keep the GTK chooser"
    fi
    rm -rf "$tmp"
}
