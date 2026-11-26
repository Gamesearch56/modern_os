#!/usr/bin/env bash
# Unprivileged coverage for storage-clean.sh. Never touches the live disk.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-storage-clean: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-storage-clean: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/storage-clean.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-storage-clean-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-storage-clean: refusing protected home" >&2; exit 1 ;;
    esac
fi

HOME_FAKE="$TMP/home"
PKG_FAKE="$TMP/pkg"
mkdir -p \
    "$HOME_FAKE/.cache/thumbnails/large" \
    "$HOME_FAKE/.cache/modern/wallpaper-thumbs" \
    "$HOME_FAKE/.cache/modern/folder-sizes/ab" \
    "$HOME_FAKE/.cache/modern/phylax-src" \
    "$HOME_FAKE/.cache/fontconfig" \
    "$HOME_FAKE/.cache/radv_builtin_shaders" \
    "$HOME_FAKE/.cache/qtshadercache-test" \
    "$HOME_FAKE/.cache/spotify" \
    "$HOME_FAKE/Documents" \
    "$PKG_FAKE"
printf 'thumb' >"$HOME_FAKE/.cache/thumbnails/large/a.png"
printf 'wall' >"$HOME_FAKE/.cache/modern/wallpaper-thumbs/a.jpg"
printf 'sizes' >"$HOME_FAKE/.cache/modern/folder-sizes/ab/one.json"
printf 'src' >"$HOME_FAKE/.cache/modern/phylax-src/keep.c"
printf 'font' >"$HOME_FAKE/.cache/fontconfig/x"
printf 'radv' >"$HOME_FAKE/.cache/radv_builtin_shaders/a"
printf 'qt' >"$HOME_FAKE/.cache/qtshadercache-test/a"
printf 'music' >"$HOME_FAKE/.cache/spotify/a"
printf 'keep' >"$HOME_FAKE/Documents/keep.txt"
printf 'oldpkg' >"$PKG_FAKE/foo-1-1-x86_64.pkg.tar.zst"

export MODERN_TEST_FIXTURE=1
export MODERN_CLEAN_HOME="$HOME_FAKE"
export MODERN_CLEAN_PKG="$PKG_FAKE"

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

out="$("$SCRIPT")"
if printf '%s\n' "$out" | grep -Eq '^done [0-9]+$' \
    && [ ! -e "$HOME_FAKE/.cache/thumbnails/large/a.png" ] \
    && [ ! -e "$HOME_FAKE/.cache/modern/wallpaper-thumbs/a.jpg" ] \
    && [ ! -e "$HOME_FAKE/.cache/modern/folder-sizes/ab/one.json" ] \
    && [ ! -e "$HOME_FAKE/.cache/radv_builtin_shaders/a" ] \
    && [ ! -e "$HOME_FAKE/.cache/qtshadercache-test/a" ] \
    && [ ! -e "$HOME_FAKE/.cache/fontconfig/x" ] \
    && [ ! -e "$PKG_FAKE/foo-1-1-x86_64.pkg.tar.zst" ] \
    && [ "$(cat "$HOME_FAKE/Documents/keep.txt")" = keep ] \
    && [ "$(cat "$HOME_FAKE/.cache/modern/phylax-src/keep.c")" = src ] \
    && [ "$(cat "$HOME_FAKE/.cache/spotify/a")" = music ]; then
    ok "wipes allowlisted caches and leaves documents"
else
    err "clean: out=$out docs=$(cat "$HOME_FAKE/Documents/keep.txt" 2>/dev/null)"
fi

mkdir -p \
    "$HOME_FAKE/Pictures/Wallpapers" \
    "$HOME_FAKE/.config/modern/wallpapers" \
    "$HOME_FAKE/.local/share" \
    "$HOME_FAKE/.cache/thumbnails/large"
printf 'photo' >"$HOME_FAKE/Pictures/Wallpapers/photo.jpg"
printf 'shipped' >"$HOME_FAKE/.config/modern/wallpapers/default.jpg"
ln -s "$TMP/missing-icons" "$HOME_FAKE/.local/share/icons"
ln -s "$HOME_FAKE/Pictures/Wallpapers/photo.jpg" "$HOME_FAKE/.cache/thumbnails/large/photo.jpg"
printf 'thumb' >"$HOME_FAKE/.cache/thumbnails/large/a.png"
"$SCRIPT" >/dev/null
if [ "$(cat "$HOME_FAKE/Pictures/Wallpapers/photo.jpg")" = photo ] \
    && [ "$(cat "$HOME_FAKE/.config/modern/wallpapers/default.jpg")" = shipped ] \
    && [ -L "$HOME_FAKE/.local/share/icons" ] \
    && [ ! -e "$HOME_FAKE/.cache/thumbnails/large/a.png" ]; then
    ok "leaves wallpapers and the icon theme alone"
else
    err "cleanup touched wallpapers or icons"
fi

mkdir -p "$TMP/evil" "$HOME_FAKE/.cache"
ln -s "$TMP/evil" "$HOME_FAKE/.cache/thumbnails"
printf 'nope' >"$TMP/evil/x"
out="$("$SCRIPT" || true)"
if [ -f "$TMP/evil/x" ]; then
    ok "skips a cache dir that is a symlink"
else
    err "followed symlink"
fi

rm -rf "$HOME_FAKE/.cache"
mkdir -p "$TMP/linked/thumbnails" "$TMP/linked/modern/phylax-src"
printf 'secret' >"$TMP/linked/thumbnails/a.png"
printf 'src' >"$TMP/linked/modern/phylax-src/keep.c"
ln -s "$TMP/linked" "$HOME_FAKE/.cache"
out="$("$SCRIPT" || true)"
if [ -f "$TMP/linked/thumbnails/a.png" ] \
    && [ "$(cat "$TMP/linked/modern/phylax-src/keep.c")" = src ]; then
    ok "refuses a .cache directory that is a symlink"
else
    err "followed a symlinked .cache"
fi

if grep -F 'Paths.script("storage-clean.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/StorageClean.qml" >/dev/null; then
    ok "Settings cleanup is one pkexec of this script"
else
    err "StorageClean.qml must pkexec storage-clean.sh"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-storage-clean: ok\n'
