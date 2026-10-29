#!/usr/bin/env bash
# Privileged, allowlisted disk cleanup. Settings pkexecs this once.
# Only regenerable caches, unused package files, and logs older than
# 14 days. Never touches documents, photos, games, or $HOME itself.
# Fixture env is ignored when running as root.
set -euo pipefail

die() { printf 'storage-clean: ERROR: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 0 ] || die "usage: storage-clean.sh"

FIXTURE=0
HOME_DIR=""
PKG_DIR="/var/cache/pacman/pkg"
if [ "$(id -u)" -ne 0 ] && [ "${MODERN_TEST_FIXTURE:-}" = "1" ] \
    && [ -n "${MODERN_CLEAN_HOME:-}" ]; then
    FIXTURE=1
    HOME_DIR="${MODERN_CLEAN_HOME}"
    PKG_DIR="${MODERN_CLEAN_PKG:-}"
fi

if [ "$FIXTURE" -eq 0 ]; then
    [ "$(id -u)" -eq 0 ] || die "must run as root (pkexec)"
    uid="${PKEXEC_UID:-${SUDO_UID:-}}"
    [[ "$uid" =~ ^[0-9]+$ ]] || die "missing calling user"
    HOME_DIR="$(getent passwd "$uid" | cut -d: -f6 || true)"
fi

[ -n "$HOME_DIR" ] || die "home missing"
HOME_DIR="$(realpath -q "$HOME_DIR" || true)"
[ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ] || die "home is not a directory"
[ "$HOME_DIR" != / ] || die "refusing /"
if [ "$FIXTURE" -eq 0 ]; then
    case "$HOME_DIR" in
        /tmp|/tmp/*|/var/tmp|/var/tmp/*) die "refusing a temp home" ;;
    esac
fi

SAVED=0
add_saved() {
    local n="${1:-0}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    SAVED=$((SAVED + n))
}

dir_bytes() {
    local d="$1" n=0
    [ -d "$d" ] || { printf '0\n'; return; }
    n="$(du -sb --one-file-system "$d" 2>/dev/null | awk '{print $1}')"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    printf '%s\n' "$n"
}

# $1 = absolute directory that must already be a realpath under HOME/.cache/
wipe_cache_dir() {
    local dir="$1" before
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0
    [ ! -L "$dir" ] || return 0
    case "$dir" in
        "$HOME_DIR"/.cache/*) ;;
        *) return 0 ;;
    esac
    before="$(dir_bytes "$dir")"
    find "$dir" -xdev -mindepth 1 -delete 2>/dev/null || true
    add_saved "$before"
}

step() { printf 'step %s\n' "$1"; }

step thumbnails
wipe_cache_dir "$HOME_DIR/.cache/thumbnails"

step gpu
wipe_cache_dir "$HOME_DIR/.cache/mesa_shader_cache"
wipe_cache_dir "$HOME_DIR/.cache/mesa_shader_cache_db"
wipe_cache_dir "$HOME_DIR/.cache/nvidia/GLCache"
wipe_cache_dir "$HOME_DIR/.cache/nvidia/ComputeCache"

step fonts
wipe_cache_dir "$HOME_DIR/.cache/fontconfig"

step packages
if [ "$FIXTURE" -eq 1 ]; then
    if [ -n "$PKG_DIR" ] && [ -d "$PKG_DIR" ] && [ ! -L "$PKG_DIR" ]; then
        before="$(dir_bytes "$PKG_DIR")"
        find "$PKG_DIR" -xdev -mindepth 1 -name '*.pkg.tar*' -delete 2>/dev/null || true
        after="$(dir_bytes "$PKG_DIR")"
        add_saved "$((before - after))"
    fi
elif [ -x /usr/bin/paccache ] && [ -d "$PKG_DIR" ]; then
    before="$(dir_bytes "$PKG_DIR")"
    /usr/bin/paccache -ruk0 >/dev/null 2>&1 || true
    /usr/bin/paccache -rk2 >/dev/null 2>&1 || true
    after="$(dir_bytes "$PKG_DIR")"
    if [ "$after" -le "$before" ]; then
        add_saved "$((before - after))"
    fi
fi

step journal
if [ "$FIXTURE" -eq 0 ] && command -v journalctl >/dev/null 2>&1; then
    freed="$(journalctl --vacuum-time=14d 2>&1 | python3 -c 'import re,sys
t=sys.stdin.read()
m=re.search(r"freed ([0-9]+(\.[0-9]+)?)([BKMGT])", t)
if not m:
    print(0)
    raise SystemExit(0)
n=float(m.group(1)); u=m.group(3)
mul={"B":1,"K":1024,"M":1024**2,"G":1024**3,"T":1024**4}[u]
print(int(n*mul))' || true)"
    add_saved "${freed:-0}"
fi

printf 'done %s\n' "$SAVED"
