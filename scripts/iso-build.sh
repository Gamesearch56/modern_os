#!/usr/bin/env bash
# Build Calamares branding and optionally the ISO under iso/out/.
# Branding matugen uses a throwaway HOME. mkarchiso needs root and
# writes only --out (default iso/out/). Never runs provision-iso.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
DO_MKARCHISO=0
WALLPAPER="$ROOT/stow/modern/.config/modern/wallpapers/default.jpg"
PROFILE_JSON="$ROOT/stow/modern/.config/modern/themes/tonal-spot-dark.json"
FIXED_JSON="$ROOT/stow/modern/.config/modern/themes/fixed-brand.json"

die() { printf 'iso-build: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'iso-build: %s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage: iso-build.sh [--mkarchiso] [--out DIR] [--tag vX.Y.Z]

Generates Calamares QSS/tokens from default.jpg under a throwaway HOME.
Writes gitignored artifacts under iso/out/. If MODERN_PROTECT_HOME is
set, refuses output under that path except a clone's iso/out.

--mkarchiso runs mkarchiso (needs root and ~8G free on --out). The live
image is this clone; Calamares late still clones --tag (or the latest
vX.Y.Z). Missing mkarchiso is not an error without the flag (branding
still succeeds). Boot the result with scripts/iso-qemu.sh.
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
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

[ -f "$WALLPAPER" ] || die "missing wallpaper $WALLPAPER"

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
if [ -z "$pin" ]; then
    pin="$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || true)"
fi
if [ -z "$pin" ]; then
    pin="$(git -C "$ROOT" tag -l 'v*.*.*' --sort=-v:refname | head -1 || true)"
fi
if [ -z "$pin" ]; then
    pin="v0.1.0"
    log "no release tag in this clone — pinning $pin"
fi
[[ "$pin" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "ISO pin must be vX.Y.Z (got $pin)"

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
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-session.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-session.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-calamares.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-calamares.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-xdg-open.sh" \
    "$AIROOTFS_OUT/usr/lib/modern/live-xdg-open.sh"
install -m 0755 "$ROOT/iso/airootfs/usr/lib/modern/live-xkb-filter.py" \
    "$AIROOTFS_OUT/usr/lib/modern/live-xkb-filter.py"
install -d -m 0755 "$AIROOTFS_OUT/usr/local/bin"
ln -sfn /usr/lib/modern/live-xdg-open.sh "$AIROOTFS_OUT/usr/local/bin/xdg-open"
printf '%s\n' "$pin" >"$AIROOTFS_OUT/usr/lib/modern/iso-pin"
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
qss = f"""
/* Generated by iso-build.sh from tokens.json — do not hand-edit hex. */
QWidget {{
    background-color: transparent;
    color: {on_surface};
}}
QMainWindow, QDialog, QWizard {{
    border-image: url("wallpaper.jpg") 0 0 0 0 stretch stretch;
    color: {on_surface};
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
QLineEdit, QComboBox, QComboBox QAbstractItemView, QSpinBox, QAbstractSpinBox {{
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
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QAbstractSpinBox:focus {{
    border: 2px solid {primary};
    padding: 9px 13px;
}}
QComboBox::drop-down {{
    border: none;
    width: 28px;
}}
QPushButton {{
    background-color: {highest};
    color: {on_surface};
    border: none;
    border-radius: 8px;
    padding: 10px 18px;
}}
QPushButton:hover {{
    background-color: {outline};
    color: {on_surface};
}}
QPushButton:default {{
    background-color: {primary};
    color: {on_primary};
}}
QPushButton:disabled {{
    background-color: {highest};
    color: {on_variant};
}}
QListView, QTreeView {{
    background-color: {highest};
    color: {on_surface};
    border: none;
    border-radius: 8px;
    padding: 4px;
}}
QProgressBar {{
    background-color: {highest};
    color: {on_surface};
    border: none;
    border-radius: 8px;
    text-align: center;
    min-height: 14px;
    max-height: 14px;
}}
QProgressBar::chunk {{
    background-color: {primary};
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
"""
open(dest, "w").write(qss)
PY
}

# Dark squircle + primary M. A filled primary tile reads as a blue box
# at sidebar size.
write_logo() {
    local tokens="$1" dest="$2"
    python3 - "$tokens" "$dest" <<'PY'
import json, math, struct, sys, zlib
path, dest = sys.argv[1], sys.argv[2]
data = json.load(open(path))
c = data.get("color") or {}

def rgb(key, fallback):
    raw = str(c.get(key) or fallback).lstrip("#")
    if len(raw) != 6:
        raw = fallback.lstrip("#")
    return tuple(int(raw[i:i+2], 16) for i in (0, 2, 4))

fill = rgb("surfaceContainerHighest", "#36343B")
mark = rgb("primary", "#D0BCFF")
size, pad, rad = 128, 8, 28

def in_round_rect(x, y):
    x0, y0, x1, y1 = pad, pad, size - pad - 1, size - pad - 1
    if x0 + rad <= x <= x1 - rad and y0 <= y <= y1:
        return True
    if y0 + rad <= y <= y1 - rad and x0 <= x <= x1:
        return True
    corners = ((x0 + rad, y0 + rad), (x1 - rad, y0 + rad),
               (x0 + rad, y1 - rad), (x1 - rad, y1 - rad))
    return any((x - cx) ** 2 + (y - cy) ** 2 <= rad ** 2 for cx, cy in corners)

def dist_seg(px, py, x1, y1, x2, y2):
    vx, vy = x2 - x1, y2 - y1
    l2 = vx * vx + vy * vy or 1.0
    t = max(0.0, min(1.0, ((px - x1) * vx + (py - y1) * vy) / l2))
    return math.hypot(px - (x1 + t * vx), py - (y1 + t * vy))

m = ((36, 96, 36, 36), (36, 36, 64, 88), (64, 88, 92, 36), (92, 36, 92, 96))
thick = 11.0
rows = []
for y in range(size):
    row = [0]
    for x in range(size):
        if not in_round_rect(x, y):
            row.extend((0, 0, 0, 0))
            continue
        on_m = any(dist_seg(x, y, *seg) <= thick for seg in m)
        r, g, b = mark if on_m else fill
        row.extend((r, g, b, 255))
    rows.append(bytes(row))

def chunk(tag, body):
    crc = zlib.crc32(tag + body) & 0xFFFFFFFF
    return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", crc)

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
png += chunk(b"IEND", b"")
open(dest, "wb").write(png)
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
    },
}, open(out, "w"), indent=2)
open(out, "a").write("\n")
PY
fi

install -m 0644 "$tokens_out" "$AIROOTFS_OUT/var/lib/modern/session/tokens.json"
write_qss "$tokens_out" "$AIROOTFS_OUT/etc/calamares/branding/modern/stylesheet.qss"
write_logo "$tokens_out" "$AIROOTFS_OUT/etc/calamares/branding/modern/logo.png"
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
