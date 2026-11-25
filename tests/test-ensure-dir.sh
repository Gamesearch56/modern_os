#!/usr/bin/env bash
# A dangling ~/.local/share/icons makes mkdir -p exit "File exists".
# Wallpaper apply used to stop there and toast that line. The helper
# replaces only a broken link, and theme-apply uses it before matugen.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-ensure-dir: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-ensure-dir: ok %s\n' "$*"; }

# shellcheck source=../scripts/lib/ensure-dir.sh
source "$ROOT/scripts/lib/ensure-dir.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
share="$tmp/home/.local/share"
mkdir -p "$share"
ln -s "$tmp/missing/icons" "$share/icons"

msg="$(ensure_real_dir "$share/icons/modern-folders/scalable/places" 2>&1)" || err "dangling link was not repaired"
if printf '%s\n' "$msg" | grep -q 'mkdir:'; then
    err "repair printed a mkdir error: $msg"
fi
if [ -d "$share/icons/modern-folders/scalable/places" ] && [ ! -L "$share/icons" ]; then
    ok "a broken icons link becomes a directory"
else
    err "icons is still not a directory"
fi

rm -rf "$share/icons"
printf 'keep' >"$share/icons"
if ensure_real_dir "$share/icons/hicolor" 2>/dev/null; then
    err "a real icons file was treated as a directory"
fi
if [ "$(cat "$share/icons")" = keep ]; then
    ok "a real icons file is left untouched"
else
    err "a real icons file was removed"
fi

apply="$ROOT/scripts/theme-apply.sh"
if grep -F 'icons/modern-folders/scalable/places' "$apply" | grep -F 'ensure_writable_dir' >/dev/null \
    && ! grep -F 'icons/modern-folders' "$apply" | grep -F 'mkdir -p' >/dev/null; then
    ok "wallpaper apply creates the icon theme without mkdir -p"
else
    err "theme-apply.sh still mkdir -p's the icon theme"
fi

thumbs="$ROOT/stow/shell/.config/quickshell/modern/Services/WallpaperThumbs.qml"
if grep -F 'root.map = ({});' "$thumbs" >/dev/null; then
    ok "wallpaper tiles drop a deleted thumbnail"
else
    err "wallpaper tiles keep a thumbnail path after it is deleted"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ensure-dir: ok\n'
