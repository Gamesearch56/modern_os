#!/usr/bin/env bash
# Build Calamares branding and optionally the ISO under iso/out/.
# Branding matugen uses a throwaway HOME. mkarchiso needs root and
# writes only --out (default iso/out/). Never runs provision-iso.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
DO_MKARCHISO=0
ALLOW_STALE_BUNDLE="${MODERN_ISO_STALE_BUNDLE:-}"
PUBLIC=""
WALLPAPER="$ROOT/stow/modern/.config/modern/wallpapers/default.jpg"
LOGO="$ROOT/iso/airootfs/etc/calamares/branding/modern/logo.png"
PROFILE_JSON="$ROOT/stow/modern/.config/modern/themes/tonal-spot-dark.json"
FIXED_JSON="$ROOT/stow/modern/.config/modern/themes/fixed-brand.json"

die() { printf 'iso-build: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'iso-build: %s\n' "$*"; }

# shellcheck source=lib/iso-bundle.sh
source "$ROOT/scripts/lib/iso-bundle.sh"

# A failed customize leaves proc (and friends) mounted. The next
# arch-chroot refuses to mount them again.
release_chroot_mounts() {
    local root="$1" mnt
    [ -d "$root" ] || return 0
    while read -r mnt; do
        [ -n "$mnt" ] || continue
        umount "$mnt" 2>/dev/null || umount -l "$mnt" 2>/dev/null || true
    done < <(findmnt -nr -o TARGET | awk -v p="$root" 'index($0, p"/")==1 { print length($0), $0 }' | sort -nr | awk '{ $1=""; sub(/^ /, ""); print }')
}

# Pacman matches the package cache against the chroot mount table.
# mkarchiso's work directory is a plain folder, so that lookup fails
# with "not enough free disk space" even when the disk has room.
# arch-chroot(8): bind the directory to itself before entering it.
install_arch_chroot_mount_wrapper() {
    local dir="$1"
    mkdir -p "$dir"
    cat >"$dir/arch-chroot" <<'EOF'
#!/bin/bash
set -euo pipefail
real=/usr/bin/arch-chroot
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -h|-S|-N|-r) args+=("$1"); shift ;;
        -u) args+=("$1" "${2:-}"); shift 2 ;;
        --) shift; break ;;
        -*) args+=("$1"); shift ;;
        *) break ;;
    esac
done
dir="${1:-}"
if [ -n "$dir" ]; then
    shift
fi
did=0
if [ -n "$dir" ] && [ -d "$dir" ] && ! mountpoint -q "$dir"; then
    mount --bind "$dir" "$dir"
    did=1
fi
set +e
"$real" "${args[@]}" ${dir:+"$dir"} "$@"
rc=$?
set -e
if [ "$did" -eq 1 ]; then
    while read -r mnt; do
        [ -n "$mnt" ] || continue
        umount "$mnt" 2>/dev/null || umount -l "$mnt" 2>/dev/null || true
    done < <(findmnt -nr -o TARGET | awk -v p="$dir" 'index($0, p"/")==1 { print length($0), $0 }' | sort -nr | awk '{ $1=""; sub(/^ /, ""); print }')
    umount "$dir" || umount -l "$dir" || true
fi
exit "$rc"
EOF
    chmod 755 "$dir/arch-chroot"
}

usage() {
    cat <<'EOF'
Usage: iso-build.sh [--mkarchiso] [--out DIR] [--tag vX.Y.Z] [--stale-bundle] [--public]

Generates Calamares QSS/tokens from default.jpg under a throwaway HOME.
Copies branding/modern/logo.png (fixed brand mark, not wallpaper-tinted).
Writes gitignored artifacts under iso/out/. If MODERN_PROTECT_HOME is
set, refuses output under that path except a clone's iso/out.

--mkarchiso runs mkarchiso (needs root and ~8G free on --out). The live
image is this clone; Calamares late still clones --tag (or the latest
vX.Y.Z in the clone). There is no hardcoded fallback pin. Missing
mkarchiso is not an error without the flag (branding still succeeds).

Only iso/ comes from your working tree unless you pass --stale-bundle.
install/, stow/ and scripts/ otherwise reach the installed system as a
clone of the pin, so the build stops if those differ from it.
--stale-bundle copies this working tree's install/, stow/ and scripts/
over that clone, including uncommitted edits. The clone's commit stays
the pin, so the installed system still reports that version.
--public leaves the GitHub deploy key out, for an image anyone may
download (scripts/iso-release.sh). Installs from it update over HTTPS.
Boot the result with scripts/iso-qemu.sh (--headless for no display).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --mkarchiso) DO_MKARCHISO=1 ;;
        --out)
            OUT="${2:-}"
            shift
            ;;
        --tag)
            MODERN_ISO_TAG="${2:-}"
            shift
            ;;
        --stale-bundle) ALLOW_STALE_BUNDLE=1 ;;
        --public) PUBLIC=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

[ -f "$WALLPAPER" ] || die "missing wallpaper $WALLPAPER"
[ -f "$LOGO" ] || die "missing branding logo $LOGO"

if command -v realpath >/dev/null 2>&1; then
    abs_out="$(realpath -m "$OUT")"
else
    abs_out="$(mkdir -p "$OUT" && readlink -f "$OUT")"
fi
protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$abs_out" in
        "$protect"|"$protect"/*)
            case "$abs_out" in
                # This checkout may still sit in a directory named modern_dotfile.
                */modern_os/iso/out|*/modern_os/iso/out/*|*/modern_dotfile/iso/out|*/modern_dotfile/iso/out/*) ;;
                *) die "refusing to write under protected home $protect ($abs_out)" ;;
            esac
            ;;
    esac
    case "$abs_out" in
        "$protect"/.config|/*/.config/modern)
            die "refusing to write live config paths"
            ;;
    esac
fi

mkdir -p "$abs_out"

pin="${MODERN_ISO_TAG:-}"
# An explicit --tag is a deliberate choice of pin, including the ISO
# workflow rebuilding an older release from main's scripts. Only an
# inferred pin can be stale by accident, so only that one is guarded.
pin_was_asked_for="${pin:+1}"
if [ -z "$pin" ]; then
    pin="$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || true)"
fi
if [ -z "$pin" ]; then
    pin="$(git -C "$ROOT" tag -l 'v*.*.*' --sort=-v:refname | head -1 || true)"
fi
[ -n "$pin" ] || die "no vX.Y.Z tag in this clone — pass --tag"
[[ "$pin" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "ISO pin must be vX.Y.Z (got $pin)"

# The bundle is cloned from this clone, not from the remote, so a tree
# without .git cannot produce one. actions/checkout falls back to a REST
# tarball whenever git is missing from the runner image, which leaves
# exactly that — and git's own "repository does not exist" names the
# destination, not the cause.
# ls-remote, not rev-parse: it resolves $ROOT the same way the clone
# below does, so an ownership refusal on $ROOT/.git surfaces here rather
# than passing a worktree check and failing mid-build.
if ! why="$(git ls-remote "$ROOT" HEAD 2>&1)"; then
    printf 'iso-build: git: %s\n' "$why" >&2
    die "$ROOT is not a usable git repository — the bundle is cloned from it"
fi
git -C "$ROOT" rev-parse -q --verify "refs/tags/$pin" >/dev/null \
    || die "$pin is not a tag in this clone — fetch tags (CI needs fetch-depth: 0)"

# A failed mkarchiso leaves proc mounted under the work directory. rm
# cannot delete those files, and a file manager then offers an unmount
# it is not allowed to perform. Drop the mounts before either happens.
if [ "$(id -u)" -eq 0 ]; then
    release_chroot_mounts "$abs_out/work/mkarchiso/x86_64/airootfs"
fi

# Without --stale-bundle the bundle Calamares installs is a clone of
# $pin. install/, stow/ and scripts/ from this tree would not be on the
# machine you then boot, which looks like the fix silently not working.
stale="$(git -C "$ROOT" diff --name-only "$pin" -- install stow scripts)"
untracked="$(git -C "$ROOT" ls-files --others --exclude-standard -- install stow scripts)"
stale="$(printf '%s\n%s\n' "$stale" "$untracked" | sed '/^$/d' | sort -u)"
if [ -n "$stale" ] && [ -z "$ALLOW_STALE_BUNDLE" ] && [ -z "$pin_was_asked_for" ]; then
    printf 'iso-build: ERROR: these differ from %s and would NOT reach the installed system:\n' \
        "$pin" >&2
    printf '%s\n' "$stale" | while IFS= read -r f; do printf '  %s\n' "$f" >&2; done
    die "commit and tag, or pass --stale-bundle to install this working tree over $pin"
fi

WORK="$abs_out/work"
BRAND_HOME="$WORK/brand-home"
AIROOTFS_OUT="$abs_out/airootfs"
rm -rf "$WORK"
# Staging lives beside work/, so the wipe above leaves it. cp -a merges,
# and a file removed from iso/airootfs (the ipconfig stand-in) then stays
# and pacman aborts with "exists in filesystem".
rm -rf "$AIROOTFS_OUT"
mkdir -p "$BRAND_HOME/.config/modern/themes" \
    "$BRAND_HOME/.config/matugen/templates" \
    "$BRAND_HOME/.config/modern/wallpapers" \
    "$AIROOTFS_OUT/etc/calamares/branding/modern" \
    "$AIROOTFS_OUT/usr/lib/modern" \
    "$AIROOTFS_OUT/usr/share/modern" \
    "$AIROOTFS_OUT/var/lib/modern/session"

cp -a "$ROOT/iso/airootfs/." "$AIROOTFS_OUT/"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/calamares-late.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-setup.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-setup.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-i18n.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-i18n.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-session.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-session.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-calamares.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-calamares.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-xdg-open.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-xdg-open.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-xkb-filter.py" \
    "$AIROOTFS_OUT/usr/lib/modern/live-xkb-filter.py"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-wifi-sim.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-wifi-sim.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-wifi-wl.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-wifi-wl.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-wifi-up.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-wifi-up.sh"
install -m 0755 "$ROOT/scripts/wifi-join.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/wifi-join.sh"
install -m 0755 "$ROOT/scripts/wifi-join-add.py" \
    "$AIROOTFS_OUT/usr/lib/modern/wifi-join-add.py"
# Cage ignores setxkbmap. This is loaded into cage and switches its
# keymap when the installer writes a layout. Without it, German still
# types Y for the key labeled Z, and the Wi-Fi password is the wrong one.
if ! command -v gcc >/dev/null 2>&1 || ! pkg-config --exists xkbcommon || ! pkg-config --exists wayland-server; then
    die "gcc, libxkbcommon and wayland are required for the installer keyboard (pacman -S --needed gcc libxkbcommon wayland)"
fi
read -r -a xkb_cflags < <(pkg-config --cflags --libs xkbcommon wayland-server)
gcc -shared -fPIC -O2 -Wall -Wextra -Wl,-z,defs -pthread \
    -o "$AIROOTFS_OUT/usr/lib/modern/live-xkb-cage.so" \
    "$ROOT/iso/releng/live-xkb-cage.c" \
    "${xkb_cflags[@]}" \
    || die "could not compile the installer keyboard helper"
chmod 0755 "$AIROOTFS_OUT/usr/lib/modern/live-xkb-cage.so"
log "installer keyboard helper compiled"
# The installed system runs the release pin's greeter, which modesets a
# dark panel and shows the firmware picture. These copies are applied
# after that pin's install, from calamares-late.sh.
if ! pkg-config --exists libdrm; then
    die "libdrm is required for the login handoff (pacman -S --needed libdrm)"
fi
read -r -a drm_cflags < <(pkg-config --cflags --libs libdrm)
gcc -shared -fPIC -O2 -Wall -Wextra -Wl,-z,defs -pthread \
    -o "$AIROOTFS_OUT/usr/lib/modern/seat-nomodeset.next" \
    "$ROOT/install/system/greetd/seat-nomodeset.c" \
    "${drm_cflags[@]}" \
    || die "could not compile the login handoff helper"
chmod 0755 "$AIROOTFS_OUT/usr/lib/modern/seat-nomodeset.next"
install -m 0755 "$ROOT/install/system/greetd/seat-cover.py" \
    "$AIROOTFS_OUT/usr/lib/modern/seat-cover.next"
install -m 0755 "$ROOT/install/system/greetd/desktop-session.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/desktop-session.next"
install -m 0755 "$ROOT/install/system/greetd/kiosk.sh" \
    "$AIROOTFS_OUT/etc/greetd/kiosk.next"
log "login handoff helper compiled"
install -m 0644 "$ROOT/install/lib/wifi-wl.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/wifi-wl.sh"
install -d -m 0755 "$AIROOTFS_OUT/usr/local/bin"
ln -sfn /usr/lib/modern/live-xdg-open.sh "$AIROOTFS_OUT/usr/local/bin/xdg-open"
printf '%s\n' "$pin" >"$AIROOTFS_OUT/usr/lib/modern/iso-pin"
bundle="$AIROOTFS_OUT/usr/share/modern/dotfile"
rm -rf "$bundle"
git clone --depth 1 --single-branch --sparse --branch "$pin" "$ROOT" "$bundle" \
    || die "could not bundle $pin into the live image"
# docs/ is what the Manual app reads on the installed system.
git -C "$bundle" sparse-checkout set --cone install stow scripts docs \
    || die "could not sparse-checkout the ISO bundle"
if [ -n "$ALLOW_STALE_BUNDLE" ]; then
    log "stale bundle: the installed system gets this working tree's install, stow and scripts"
    overlay_worktree_bundle "$ROOT" "$bundle"
fi
# Installer languages, regional locales and keyboard defaults follow the
# bundle, i.e. what the installed desktop can actually show. --strict: the
# build host has glibc SUPPORTED, zone.tab and xkb base.lst, so a language
# or layout glibc/xkb do not know stops here, not in a user's install.
ISO_INSTALLER_LOCALES="$AIROOTFS_OUT/usr/lib/modern/installer-locales.json"
brand_lang="$AIROOTFS_OUT/etc/calamares/branding/modern/lang"
install -d -m 0755 "$brand_lang"
python3 "$ROOT/scripts/installer-locales.py" --strict \
    --root "$bundle" --fallback-root "$ROOT" \
    --json "$ISO_INSTALLER_LOCALES" \
    --locale-gen "$AIROOTFS_OUT/etc/locale.gen" \
    --branding-ts "$brand_lang" \
    || die "languages.json / keyboard-layouts.json failed validation (see above)"
chmod 0644 "$ISO_INSTALLER_LOCALES" "$AIROOTFS_OUT/etc/locale.gen"
export ISO_INSTALLER_LOCALES
log "installer languages: $(jq -r '[.locales[] | .calamares] | join(" ")' "$ISO_INSTALLER_LOCALES")"
# shellcheck source=lib/deploy-key.sh
source "$ROOT/scripts/lib/deploy-key.sh"
# $AIROOTFS_OUT outlives a build, so a key from an earlier private build
# would otherwise still be in it.
rm -f "$AIROOTFS_OUT/usr/lib/modern/deploy_key"
if [ -n "$PUBLIC" ]; then
    log "public image — no deploy key; installs update over HTTPS"
elif ! stage_deploy_key "$AIROOTFS_OUT/usr/lib/modern/deploy_key" \
    "$ROOT/secrets/github-deploy-key"; then
    die "secrets/github-deploy-key must be an OpenSSH private key owned by you, mode 600, not a symlink"
fi
if [ -f "$AIROOTFS_OUT/usr/lib/modern/deploy_key" ]; then
    log "embedded read-only GitHub deploy key for release updates"
else
    log "no secrets/github-deploy-key — release checks use HTTPS"
fi
install -m 0644 "$WALLPAPER" "$AIROOTFS_OUT/usr/share/modern/wallpaper.jpg"
install -m 0644 "$WALLPAPER" "$AIROOTFS_OUT/var/lib/modern/session/wallpaper.jpg"
install -m 0644 "$WALLPAPER" "$AIROOTFS_OUT/etc/calamares/branding/modern/wallpaper.jpg"

cp "$WALLPAPER" "$BRAND_HOME/.config/modern/wallpapers/default.jpg"
cp "$PROFILE_JSON" "$BRAND_HOME/.config/modern/themes/tonal-spot-dark.json"
cp "$FIXED_JSON" "$BRAND_HOME/.config/modern/themes/fixed-brand.json"
cp "$ROOT/stow/theme/.config/matugen/templates/tokens.json.template" \
    "$BRAND_HOME/.config/matugen/templates/tokens.json.template"
cat >"$BRAND_HOME/.config/matugen/config.toml" <<'TOML'
[config]
[templates.tokens_json]
input_path = "~/.config/matugen/templates/tokens.json.template"
output_path = "~/.config/modern/tokens.json"
TOML

write_qss() {
    python3 "$ROOT/scripts/lib/iso-calamares-qss.py" "$1" "$2" \
        || die "could not write Calamares stylesheet"
}

tokens_out="$BRAND_HOME/.config/modern/tokens.json"
ran_matugen=0
if command -v matugen >/dev/null 2>&1; then
    log "matugen branding in throwaway HOME $BRAND_HOME"
    if env HOME="$BRAND_HOME" XDG_CONFIG_HOME="$BRAND_HOME/.config" \
        XDG_STATE_HOME="$BRAND_HOME/.local/state" \
        XDG_DATA_HOME="$BRAND_HOME/.local/share" \
        XDG_CACHE_HOME="$BRAND_HOME/.cache" \
        matugen -c "$BRAND_HOME/.config/matugen/config.toml" \
            -t scheme-tonal-spot -m dark \
            image "$WALLPAPER" --prefer saturation; then
        ran_matugen=1
    fi
fi
if [ "$ran_matugen" -eq 0 ] || [ ! -f "$tokens_out" ]; then
    log "matugen missing or failed — fixed-brand seed fallback"
    seed="$(jq -r '.fixedSeed // "#6750A4"' "$FIXED_JSON")"
    python3 - "$seed" "$tokens_out" <<'PY'
import json, sys
seed = sys.argv[1]
out = sys.argv[2]
# MD3 dark baseline for the shipped fixed-brand seed (same roles as Commons).
json.dump({
    "mode": "dark",
    "sourceColor": seed,
    "color": {
        "primary": "#D0BCFF",
        "onPrimary": "#381E72",
        "surface": "#141218",
        "onSurface": "#E6E0E9",
        "onSurfaceVariant": "#CAC4D0",
        "outline": "#938F99",
        "surfaceContainerHighest": "#36343B",
        "primaryContainer": "#4F378B",
        "onPrimaryContainer": "#EADDFF",
    },
}, open(out, "w"), indent=2)
open(out, "a").write("\n")
PY
fi

install -m 0644 "$tokens_out" "$AIROOTFS_OUT/var/lib/modern/session/tokens.json"
write_qss "$tokens_out" "$AIROOTFS_OUT/etc/calamares/branding/modern/stylesheet.qss"
install -m 0644 "$LOGO" "$AIROOTFS_OUT/etc/calamares/branding/modern/logo.png"
brand_ts=("$brand_lang"/calamares-modern_*.ts)
if [ -e "${brand_ts[0]}" ]; then
    lrelease_bin=""
    # Arch qt6-tools ships lrelease6 (/usr/lib/qt6/bin/lrelease), not
    # Debian's lrelease-qt6. sudo's PATH still includes /usr/bin.
    for c in lrelease6 lrelease-qt6 lrelease /usr/lib/qt6/bin/lrelease; do
        if command -v "$c" >/dev/null 2>&1; then
            lrelease_bin="$(command -v "$c")"
            break
        fi
        if [ -x "$c" ]; then
            lrelease_bin="$c"
            break
        fi
    done
    if [ -n "$lrelease_bin" ]; then
        for ts in "${brand_ts[@]}"; do
            "$lrelease_bin" "$ts" -qm "${ts%.ts}.qm" >/dev/null \
                || die "lrelease failed for $ts"
            log "compiled branding ${ts%.ts}.qm"
        done
    elif [ "$DO_MKARCHISO" -eq 1 ]; then
        die "lrelease6 missing (pacman -S --needed qt6-tools) — needed for the translated slideshow"
    else
        log "lrelease6 missing — slideshow stays English until qt6-tools is installed"
    fi
fi
printf '%s\n' "$pin" >"$abs_out/iso-pin"
log "branding written under $abs_out (pin $pin)"

if [ "$DO_MKARCHISO" -eq 0 ]; then
    log "skipping mkarchiso (pass --mkarchiso as root to build the image)"
    exit 0
fi
[ "$(id -u)" -eq 0 ] || die "mkarchiso needs root: sudo $0 --mkarchiso"
command -v mkarchiso >/dev/null 2>&1 || die "mkarchiso not on PATH (pacman -S --needed archiso)"

# Squashfs plus the ISO both live under --out. /tmp is often a small
# tmpfs (v0.1.3: 1.7G squashfs left 1.5G, ISO needed 2.7G).
avail_kib="$(df -Pk "$abs_out" | awk 'NR==2 { print $4 }')"
[[ "$avail_kib" =~ ^[0-9]+$ ]] || die "could not read free space on $abs_out"
need_kib=$((8 * 1024 * 1024))
if [ "$avail_kib" -lt "$need_kib" ]; then
    die "need 8G free on $abs_out for squashfs+ISO (have $((avail_kib / 1024))M). Avoid /tmp."
fi
log "mkarchiso out $abs_out ($((avail_kib / 1024))M free)"

PROFILE_WORK="$WORK/profile"
mkdir -p "$PROFILE_WORK"
if [ -d /usr/share/archiso/configs/releng ]; then
    cp -a /usr/share/archiso/configs/releng/. "$PROFILE_WORK/"
fi
if [ -f "$ROOT/iso/releng/profiledef.sh" ]; then
    install -m 0755 "$ROOT/iso/releng/profiledef.sh" "$PROFILE_WORK/profiledef.sh"
fi
# Absent on a build with no deploy key. mkarchiso warns on a
# file_permissions entry whose file is not in the image, so add it
# only when this ISO actually carries the key. cp into the image
# drops the mode; this puts it back to root-only.
if [ -f "$PROFILE_WORK/profiledef.sh" ] \
    && [ -f "$AIROOTFS_OUT/usr/lib/modern/deploy_key" ]; then
    printf 'file_permissions+=(["/usr/lib/modern/deploy_key"]="0:0:600")\n' \
        >>"$PROFILE_WORK/profiledef.sh"
fi
if [ -f "$ROOT/iso/releng/packages.x86_64" ]; then
    install -m 0644 "$ROOT/iso/releng/packages.x86_64" "$PROFILE_WORK/packages.x86_64"
fi
# Guest serial for iso-qemu.sh --headless (live-session logs to ttyS0).
for f in "$PROFILE_WORK"/efiboot/loader/entries/01-archiso-linux.conf \
    "$PROFILE_WORK"/efiboot/loader/entries/02-archiso-speech-linux.conf; do
    if [ -f "$f" ] && ! grep -q 'console=ttyS0' "$f"; then
        sed -i 's/^options[[:space:]]\{1,\}/options  console=ttyS0,115200 console=tty0 /' "$f"
    fi
done
for f in "$PROFILE_WORK"/syslinux/archiso_sys-linux.cfg \
    "$PROFILE_WORK"/syslinux/archiso_pxe-linux.cfg; do
    if [ -f "$f" ] && ! grep -q 'console=ttyS0' "$f"; then
        sed -i 's/^APPEND /APPEND console=ttyS0,115200 console=tty0 /' "$f"
    fi
done
# Releng names vmlinuz-linux. This image only ships linux-zen.
find "$PROFILE_WORK" -type f \( -name '*.conf' -o -name '*.cfg' -o -name '*.preset' \) -print0 \
    | xargs -0 -r sed -i \
        -e 's/vmlinuz-linux\([^a-z-]\|$\)/vmlinuz-linux-zen\1/g' \
        -e 's/initramfs-linux\.img/initramfs-linux-zen.img/g'
rm -f "$PROFILE_WORK/airootfs/etc/mkinitcpio.d/linux.preset"
# Persist AUR .pkg.tar.* beside --out so rm -rf $WORK does not wipe them.
MODERN_ISO_AUR_CACHE="${MODERN_ISO_AUR_CACHE:-$abs_out/aur-cache}"
# shellcheck source=lib/iso-aur-repo.sh
source "$ROOT/scripts/lib/iso-aur-repo.sh"
# shellcheck source=lib/iso-local-pkgs.sh
source "$ROOT/scripts/lib/iso-local-pkgs.sh"
iso_build_finish() {
    iso_aur_cleanup
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ] && [ -d "$abs_out" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$abs_out" 2>/dev/null || true
    fi
}
trap iso_build_finish EXIT
iso_attach_aur_repo "$PROFILE_WORK"
iso_sanitize_package_list "$PROFILE_WORK/packages.x86_64"
mkdir -p "$PROFILE_WORK/airootfs"
cp -a "$AIROOTFS_OUT/." "$PROFILE_WORK/airootfs/"
chroot_wrap="$WORK/arch-chroot-bin"
install_arch_chroot_mount_wrapper "$chroot_wrap"
ISO_VERSION="$pin" PATH="$chroot_wrap:$PATH" mkarchiso -v -w "$WORK/mkarchiso" -o "$abs_out" "$PROFILE_WORK"
log "ISO written under $abs_out (live image is this clone; late install still clones $pin)"
log "boot it with: scripts/iso-qemu.sh"
