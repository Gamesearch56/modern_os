#!/usr/bin/env bash
# Build Calamares branding and optionally the ISO under iso/out/.
# Branding matugen uses a throwaway HOME. mkarchiso needs root and
# writes only --out (default iso/out/). Never runs provision-iso.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
DO_MKARCHISO=0
ALLOW_STALE_BUNDLE="${MODERN_ISO_STALE_BUNDLE:-}"
WALLPAPER="$ROOT/stow/modern/.config/modern/wallpapers/default.jpg"
LOGO="$ROOT/iso/airootfs/etc/calamares/branding/modern/logo.png"
PROFILE_JSON="$ROOT/stow/modern/.config/modern/themes/tonal-spot-dark.json"
FIXED_JSON="$ROOT/stow/modern/.config/modern/themes/fixed-brand.json"

die() { printf 'iso-build: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'iso-build: %s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage: iso-build.sh [--mkarchiso] [--out DIR] [--tag vX.Y.Z] [--stale-bundle]

Generates Calamares QSS/tokens from default.jpg under a throwaway HOME.
Copies branding/modern/logo.png (fixed brand mark, not wallpaper-tinted).
Writes gitignored artifacts under iso/out/. If MODERN_PROTECT_HOME is
set, refuses output under that path except a clone's iso/out.

--mkarchiso runs mkarchiso (needs root and ~8G free on --out). The live
image is this clone; Calamares late still clones --tag (or the latest
vX.Y.Z in the clone). There is no hardcoded fallback pin. Missing
mkarchiso is not an error without the flag (branding still succeeds).

Only iso/ comes from your working tree. install/, stow/ and scripts/ reach
the installed system through a clone of the pin, so the build stops if
those differ from it. --stale-bundle builds the pin's copy anyway.
Boot the result with scripts/iso-qemu.sh (--headless for CI).
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
                */modern_dotfile/iso/out|*/modern_dotfile/iso/out/*) ;;
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
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
    || die "$ROOT is not a git repository — the bundle is cloned from it"
git -C "$ROOT" rev-parse -q --verify "refs/tags/$pin" >/dev/null \
    || die "$pin is not a tag in this clone — fetch tags (CI needs fetch-depth: 0)"

# The live ISO is this working tree, but the bundle Calamares installs from
# is a clone of $pin. Edit install/ or stow/ without tagging and the change
# is on the ISO yet absent from the installed system, which looks like the
# fix silently not working.
stale="$(git -C "$ROOT" diff --name-only "$pin" -- install stow scripts)"
untracked="$(git -C "$ROOT" ls-files --others --exclude-standard -- install stow scripts)"
stale="$(printf '%s\n%s\n' "$stale" "$untracked" | sed '/^$/d' | sort -u)"
if [ -n "$stale" ] && [ -z "$ALLOW_STALE_BUNDLE" ] && [ -z "$pin_was_asked_for" ]; then
    printf 'iso-build: ERROR: these differ from %s and would NOT reach the installed system:\n' \
        "$pin" >&2
    printf '%s\n' "$stale" | while IFS= read -r f; do printf '  %s\n' "$f" >&2; done
    die "commit and tag, or pass --stale-bundle to install $pin's copy anyway"
fi

WORK="$abs_out/work"
BRAND_HOME="$WORK/brand-home"
AIROOTFS_OUT="$abs_out/airootfs"
rm -rf "$WORK"
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
[ -f "$ROOT/iso/releng/installer-locales.json" ] \
    || die "missing $ROOT/iso/releng/installer-locales.json"
install -m 0644 "$ROOT/iso/releng/installer-locales.json" \
    "$AIROOTFS_OUT/usr/lib/modern/installer-locales.json"
install -d -m 0755 "$AIROOTFS_OUT/usr/local/bin"
ln -sfn /usr/lib/modern/live-xdg-open.sh "$AIROOTFS_OUT/usr/local/bin/xdg-open"
printf '%s\n' "$pin" >"$AIROOTFS_OUT/usr/lib/modern/iso-pin"
bundle="$AIROOTFS_OUT/usr/share/modern/dotfile"
rm -rf "$bundle"
git clone --depth 1 --single-branch --branch "$pin" "$ROOT" "$bundle" \
    || die "could not bundle $pin into the live image"
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
    local tokens="$1" dest="$2"
    python3 - "$tokens" "$dest" <<'PY'
import json, sys
path, dest = sys.argv[1], sys.argv[2]
data = json.load(open(path))
c = data.get("color") or {}
def hx(key, fallback):
    v = str(c.get(key) or fallback)
    if not v.startswith("#"):
        v = "#" + v
    return v
primary = hx("primary", "#6750A4")
on_primary = hx("onPrimary", "#FFFFFF")
surface = hx("surface", "#141218")
on_surface = hx("onSurface", "#E6E0E9")
on_variant = hx("onSurfaceVariant", "#CAC4D0")
outline = hx("outline", "#938F99")
highest = hx("surfaceContainerHighest", "#36343B")
primary_container = hx("primaryContainer", "#4F378B")
on_primary_container = hx("onPrimaryContainer", "#EADDFF")
qss = f"""
/* Generated by iso-build.sh from tokens.json — do not hand-edit hex. */
QWidget {{
    color: {on_surface};
    font-family: Inter;
}}
QMainWindow, #mainApp {{
    background-color: {surface};
    color: {on_surface};
}}
QStackedWidget, QAbstractScrollArea, QAbstractScrollArea::viewport, #scrollAreaWidgetContents, #summaryStep {{
    background-color: {surface};
    color: {on_surface};
    border: none;
}}
#summaryContent, #summaryItemWrap, #summaryPartition, #summaryTitle, #summaryItemTitle {{
    background-color: {surface};
    color: {on_surface};
}}
#summaryItemBody {{
    background-color: {highest};
    color: {on_surface};
}}
QQuickWidget {{
    background-color: {surface};
}}
QDialog, QWizard, QMessageBox, QMessageBox QLabel, QMessageBox QPushButton {{
    background-color: {highest};
    color: {on_surface};
    border-image: none;
}}
QLabel, QCheckBox, QRadioButton, QFrame, QGroupBox {{
    background-color: transparent;
    border: none;
}}
QGroupBox::title {{
    background-color: transparent;
    color: {on_variant};
    padding: 4px 0;
}}
QStackedWidget QLabel {{
    padding: 10px 0 4px 0;
    color: {on_surface};
}}
#partitionLabel {{
    color: {on_surface};
    background-color: {surface};
}}
QLineEdit, QSpinBox, QAbstractSpinBox {{
    background-color: {highest};
    color: {on_surface};
    border: 1px solid {outline};
    border-radius: 8px;
    padding: 10px 14px;
    min-height: 20px;
    margin: 0 0 8px 0;
    selection-background-color: {primary};
    selection-color: {on_primary};
}}
QComboBox {{
    background-color: {highest};
    color: {on_surface};
    border: 1px solid {outline};
    padding: 0 14px;
    min-height: 40px;
    margin: 0;
    combobox-popup: 0;
    selection-background-color: {primary};
    selection-color: {on_primary};
}}
QLineEdit:focus, QSpinBox:focus, QAbstractSpinBox:focus {{
    border: 2px solid {primary};
    padding: 9px 13px;
}}
QComboBox:focus {{
    border: 2px solid {primary};
}}
QComboBox::drop-down {{
    border: none;
    background: transparent;
    width: 28px;
}}
QComboBoxPrivateContainer, QComboBox QFrame {{
    background-color: {highest};
    color: {on_surface};
    border: 1px solid {outline};
}}
QComboBox QAbstractItemView {{
    background-color: {highest};
    color: {on_surface};
    border: 1px solid {outline};
    padding: 0;
    outline: 0;
    selection-background-color: {primary};
    selection-color: {on_primary};
}}
QComboBox QAbstractItemView::viewport, QComboBox QAbstractItemView QWidget {{
    background-color: {highest};
    color: {on_surface};
}}
QComboBox QAbstractItemView::item {{
    background-color: {highest};
    color: {on_surface};
    min-height: 28px;
    padding: 6px 12px;
}}
QComboBox QAbstractItemView::item:selected, QComboBox QAbstractItemView::item:hover {{
    background-color: {primary};
    color: {on_primary};
}}
QMenu {{
    background-color: {highest};
    color: {on_surface};
    border: 1px solid {outline};
    padding: 4px;
}}
QMenu::item {{
    background-color: transparent;
    padding: 8px 14px;
}}
QMenu::item:selected {{
    background-color: {primary};
    color: {on_primary};
}}
QPushButton {{
    background-color: {highest};
    color: {on_surface};
    border: none;
    border-radius: 20px;
    padding: 10px 18px;
    min-height: 20px;
}}
QPushButton:hover {{
    background-color: {outline};
    color: {on_surface};
}}
QPushButton:default, #view-button-next {{
    background-color: {primary};
    color: {on_primary};
}}
QPushButton:default:hover, #view-button-next:hover {{
    background-color: {primary};
    color: {on_primary};
}}
QPushButton:disabled {{
    background-color: {highest};
    color: {on_variant};
}}
QToolButton, QToolButton:hover, QToolButton:pressed, QToolButton:checked {{
    background-color: {surface};
    color: {on_surface};
    border: none;
    padding: 8px 12px;
}}
#view-button-back, #view-button-cancel {{
    margin: 4px 6px;
}}
#view-button-next {{
    margin: 4px 6px;
}}
QMessageBox QPushButton, QDialog QPushButton {{
    background-color: {highest};
    color: {on_surface};
    border-radius: 20px;
}}
QMessageBox QPushButton:default, QDialog QPushButton:default {{
    background-color: {primary};
    color: {on_primary};
}}
QListView, QTreeView, QListWidget, QTreeWidget {{
    background-color: {highest};
    color: {on_surface};
    border: none;
    border-radius: 8px;
    padding: 4px;
    outline: 0;
    selection-background-color: {primary};
    selection-color: {on_primary};
}}
QProgressBar {{
    background-color: {highest};
    color: {on_primary_container};
    border: none;
    border-radius: 8px;
    text-align: center;
    min-height: 14px;
    max-height: 14px;
}}
QProgressBar::chunk {{
    background-color: {primary_container};
    border-radius: 8px;
}}
QTextBrowser, QPlainTextEdit {{
    background-color: {highest};
    color: {on_surface};
    border: none;
    border-radius: 12px;
    padding: 16px;
}}
QScrollBar:vertical {{
    background: transparent;
    width: 10px;
    margin: 4px 2px;
}}
QScrollBar::handle:vertical {{
    background: {outline};
    border-radius: 5px;
    min-height: 24px;
}}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
    height: 0;
}}
#networkPage QLabel {{
    padding: 0;
    color: {on_surface};
}}
#networkOkPage, #networkWifiPage {{
    background-color: {surface};
}}
#networkOkBadge {{
    background-color: {primary_container};
    color: {on_primary_container};
    border-radius: 56px;
    font-size: 48px;
}}
#networkOkTitle {{
    color: {on_surface};
    font-size: 22px;
    font-weight: 500;
}}
#networkOkHint, #networkHint, #networkNearbyTitle {{
    color: {on_variant};
}}
#wifiList {{
    background-color: {highest};
    border: none;
    border-radius: 12px;
    padding: 8px;
    outline: 0;
}}
#wifiList::item {{
    background-color: transparent;
    color: {on_surface};
    min-height: 28px;
    padding: 10px 14px;
    border-radius: 8px;
}}
#wifiList::item:selected, #wifiList::item:hover {{
    background-color: {primary_container};
    color: {on_primary_container};
}}
#networkPasswordCard {{
    background-color: {highest};
    border-radius: 12px;
}}
#wifiPassword {{
    margin: 0;
}}
#finishedBadge {{
    background-color: {primary_container};
    color: {on_primary_container};
    border-radius: 56px;
    font-size: 48px;
}}
#finishedMainText {{
    color: {on_surface};
    font-size: 20px;
}}
#finishedRestart {{
    background-color: {primary};
    color: {on_primary};
    border: none;
    border-radius: 24px;
    padding: 14px 40px;
    font-size: 17px;
    font-weight: 500;
    min-height: 24px;
}}
#finishedRestart:hover {{
    background-color: {on_primary_container};
    color: {primary_container};
}}
"""
open(dest, "w").write(qss)
PY
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
brand_lang="$AIROOTFS_OUT/etc/calamares/branding/modern/lang"
install -d -m 0755 "$brand_lang"
if [ -f "$ROOT/iso/airootfs/etc/calamares/branding/modern/lang/calamares-modern_de.ts" ]; then
    install -m 0644 "$ROOT/iso/airootfs/etc/calamares/branding/modern/lang/calamares-modern_de.ts" \
        "$brand_lang/calamares-modern_de.ts"
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
        "$lrelease_bin" "$brand_lang/calamares-modern_de.ts" \
            -qm "$brand_lang/calamares-modern_de.qm" >/dev/null
        log "compiled branding $brand_lang/calamares-modern_de.qm"
    elif [ "$DO_MKARCHISO" -eq 1 ]; then
        die "lrelease6 missing (pacman -S --needed qt6-tools) — needed for German slideshow"
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
if [ -f "$ROOT/iso/releng/packages.x86_64" ]; then
    cat "$ROOT/iso/releng/packages.x86_64" >>"$PROFILE_WORK/packages.x86_64"
fi
# Guest serial for iso-qemu.sh --headless / CI smoke (live-session logs to ttyS0).
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
# shellcheck source=lib/iso-aur-repo.sh
source "$ROOT/scripts/lib/iso-aur-repo.sh"
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
ISO_VERSION="$pin" mkarchiso -v -w "$WORK/mkarchiso" -o "$abs_out" "$PROFILE_WORK"
log "ISO written under $abs_out (live image is this clone; late install still clones $pin)"
log "boot it with: scripts/iso-qemu.sh"
