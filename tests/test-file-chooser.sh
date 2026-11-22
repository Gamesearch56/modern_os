#!/usr/bin/env bash
# File chooser portal: backend (test-file-chooser.py), the modern-portal
# package, the bus and portal registrations, and the Files chooser hooks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$ROOT/stow/shell/.config/quickshell/modern"
PKG="$ROOT/install/packages/modern-portal"
BUS="$ROOT/stow/xdg/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.modern.service"
FAIL=0
err() { printf 'test-file-chooser: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-file-chooser: ok %s\n' "$*"; }
same() { if [ "$2" = "$1" ]; then ok "$3"; else err "$3 (got: $2)"; fi; }
has() { if grep -Fq -- "$1" "$2"; then ok "$3"; else err "$3"; fi; }

python3 "$ROOT/tests/test-file-chooser.py" || FAIL=1

name="org.freedesktop.impl.portal.desktop.modern"
same "$name" "$(sed -n 's/^DBusName=//p' "$PKG/modern.portal")" "the portal file names the backend's bus"
same "$name" "$(sed -n 's/^Name=//p' "$BUS")" "the session service starts that bus name"
has 'BUS_NAME = "'"$name"'"' "$ROOT/scripts/file-chooser-portal.py" "the backend owns that bus name"
has "org.freedesktop.impl.portal.FileChooser" "$PKG/modern.portal" "the portal file offers only the file chooser"
has "/scripts/file-chooser-portal.py" "$BUS" "the session service runs the backend from the checkout"
if [ -x "$ROOT/scripts/file-chooser-portal.py" ]; then ok "the backend is executable"; else err "the backend is executable"; fi

sum="$(sha256sum "$PKG/modern.portal" | cut -d' ' -f1)"
has "sha256sums=('$sum')" "$PKG/PKGBUILD" "the PKGBUILD checksum matches modern.portal"
has "usr/share/xdg-desktop-portal/portals/modern.portal" "$PKG/PKGBUILD" "the package installs where xdg-desktop-portal reads backends"

for conf in "$ROOT/stow/xdg/.config/xdg-desktop-portal/hyprland-portals.conf" "$ROOT/install/system/portals/hyprland-portals.conf"; do
    same "modern;gtk" "$(sed -n 's/^org.freedesktop.impl.portal.FileChooser=//p' "$conf")" "${conf#"$ROOT"/} prefers Files and falls back to GTK"
done

has "singleton FilesRequest 1.0 FilesRequest.qml" "$QS/Services/qmldir" "FilesRequest is registered"
has "singleton FilesSaveAs 1.0 FilesSaveAs.qml" "$QS/Services/qmldir" "FilesSaveAs is registered"
has "FilesRequest.begin()" "$QS/files-window.qml" "a Files window starts the request it was given"
has "anchors.bottomMargin: choose.reserve" "$QS/Modules/Files/Module.qml" "the chooser controls sit in their own row below the files"
if grep -q "ChooseBar" "$QS/Modules/Files/Toolbar.qml"; then err "the title bar stays free of chooser controls"; else ok "the title bar stays free of chooser controls"; fi
has "ReplaceConfirm {}" "$QS/Modules/Files/Dialogs.qml" "saving over a file asks first"
has "Dialogs {}" "$QS/Modules/Files/Module.qml" "the Files window carries its dialogs"

has '/install/lib/portal.sh"' "$ROOT/install/install.sh" "install.sh sources portal.sh"
has "portal_apply" "$ROOT/install/install.sh" "install.sh installs the portal package"
if grep -Eq "^python-gobject([[:space:]]|$)" "$ROOT/install/manifests/10-desktop.txt"; then ok "python-gobject is in the desktop manifest"; else err "python-gobject is in the desktop manifest"; fi

# shellcheck source=../scripts/lib/pkg-name.sh
source "$ROOT/scripts/lib/pkg-name.sh"
# shellcheck source=../scripts/lib/root-plan.sh
source "$ROOT/scripts/lib/root-plan.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-chooser-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
printf 'pkg jq\nportal\n' >"$TMP/plan"
read_root_plan "$TMP/plan"
same "1 jq" "$ROOT_PLAN_PORTAL ${ROOT_PLAN_PKGS[*]}" "the root plan carries the portal step"
if PKEXEC_UID="" root_plan_portal_pkg >/dev/null 2>&1; then err "no caller, no portal package"; else ok "no caller, no portal package"; fi
has 'root_plan_portal_pkg' "$ROOT/scripts/update-apply.sh" "the update's root step installs only the checked package"
has 'MODERN_PACMAN_NOSANDBOX' "$ROOT/install/lib/portal.sh" "the installer chroot installs the portal without pacman's sandbox"

has "scripts/lib/iso-local-pkgs.sh\"" "$ROOT/scripts/iso-build.sh" "the ISO build loads its own packages"
has "iso_local_packages \"\$repo\"" "$ROOT/scripts/lib/iso-aur-repo.sh" "the ISO local repo gets ModernOS's packages"
has 'report_portal' "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" "a fresh install reports the portal"
(
    # shellcheck source=../scripts/lib/iso-local-pkgs.sh
    source "$ROOT/scripts/lib/iso-local-pkgs.sh"
    ISO_AUR_BUILDER=nobody
    chown() { :; }
    log() { :; }
    iso_aur_makepkg() { : >"$1/modern-portal-1-1-any.pkg.tar.zst"; }
    mkdir -p "$TMP/iso/repo" "$TMP/iso/build" "$TMP/iso/profile"
    printf 'base\n' >"$TMP/iso/profile/packages.x86_64"
    iso_local_packages "$TMP/iso/repo" "$TMP/iso/build" "$TMP/iso/profile"
    iso_local_packages "$TMP/iso/repo" "$TMP/iso/build" "$TMP/iso/profile"
)
if [ -f "$TMP/iso/repo/modern-portal-1-1-any.pkg.tar.zst" ]; then ok "the ISO repo holds modern-portal"; else err "the ISO repo holds modern-portal"; fi
same "1" "$(grep -cx modern-portal "$TMP/iso/profile/packages.x86_64")" "the live image installs modern-portal once"

if command -v makepkg >/dev/null 2>&1 && command -v bsdtar >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
    REPO_ROOT="$ROOT"
    log_ok() { :; }; log_info() { :; }; log_warn() { :; }
    # shellcheck source=../install/lib/portal.sh
    source "$ROOT/install/lib/portal.sh"
    built="$(portal_build "$TMP/out" 2>/dev/null || true)"
    if [ -n "$built" ] && bsdtar -tf "$built" | grep -qx "usr/share/xdg-desktop-portal/portals/modern.portal"; then
        ok "makepkg builds modern-portal with the portal file"
    else
        err "makepkg builds modern-portal with the portal file"
    fi
    if [ -z "$(find "$PKG" -mindepth 1 ! -name PKGBUILD ! -name modern.portal)" ]; then ok "the build leaves the checkout clean"; else err "the build leaves the checkout clean"; fi
else
    ok "makepkg not available; package build skipped"
fi

[ "$FAIL" -eq 0 ] || exit 1
