#!/usr/bin/env bash
# Copies the live wallpaper plus derived (blurred, boot-downscaled) and
# a tokens.json snapshot into a world-readable shared dir so the greeter
# and Plymouth never need to read $HOME (docs/DECISIONS.md #14).
# Does NOT regenerate Plymouth or run mkinitcpio — that's plymouth-sync.sh
# plus a gated operator step (docs/DECISIONS.md #13).
#
# Usage: wallpaper-sync.sh [image]
set -euo pipefail

log()  { printf '[wallpaper-sync] %s\n' "$*"; }
warn() { printf '[wallpaper-sync] WARN %s\n' "$*" >&2; }
die()  { printf '[wallpaper-sync] ERROR %s\n' "$*" >&2; exit 1; }

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
SHARED="${MODERN_SESSION_DIR:-/var/lib/modern/session}"

# Gated tmpfiles.d may not have been applied yet — fall back so the
# picker still produces assets a future greeter can consume.
if [ ! -d "$SHARED" ]; then
    SHARED="${XDG_STATE_HOME:-$HOME/.local/state}/modern/session"
    mkdir -p "$SHARED"
    log "using fallback $SHARED (gated /var/lib/modern/session not present)"
fi

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    [ -f "$STATE_DIR/current-wallpaper" ] || die "no image given and $STATE_DIR/current-wallpaper missing"
    IMAGE="$(cat "$STATE_DIR/current-wallpaper")"
fi
[ -f "$IMAGE" ] || die "wallpaper not found: $IMAGE"

mkdir -p "$SHARED"

# greetd_apply leaves 0644 root:modern files. magick opens the destination
# in place, so that fails even though the 2775 directory lets group `modern`
# replace them with mv.
stage_tmp() {
    local dest="$1"
    local ext="${dest##*.}"
    mktemp --suffix=".${ext}" -p "$(dirname "$dest")" tmp.XXXXXX
}

commit_tmp() {
    local tmp="$1" dest="$2"
    chmod a+r "$tmp" || true
    mv -f "$tmp" "$dest"
}

copy_as_jpeg() {
    local src="$1" dest="$2"
    local tmp
    tmp="$(stage_tmp "$dest")"
    if command -v magick >/dev/null 2>&1; then
        magick "$src" "$tmp" || { rm -f "$tmp"; return 1; }
    elif command -v convert >/dev/null 2>&1; then
        convert "$src" "$tmp" || { rm -f "$tmp"; return 1; }
    else
        cp "$src" "$tmp" || { rm -f "$tmp"; return 1; }
    fi
    commit_tmp "$tmp" "$dest"
}

magick_to() {
    local dest="$1"
    shift
    local tmp
    tmp="$(stage_tmp "$dest")"
    if magick "$@" "$tmp"; then
        commit_tmp "$tmp" "$dest"
    else
        rm -f "$tmp"
        return 1
    fi
}

copy_as_jpeg "$IMAGE" "$SHARED/wallpaper.jpg"

if command -v magick >/dev/null 2>&1; then
    magick_to "$SHARED/wallpaper-boot.jpg" "$IMAGE" -resize '1920x1080>'
    magick_to "$SHARED/wallpaper-blur.jpg" "$SHARED/wallpaper-boot.jpg" -blur 0x16
elif command -v convert >/dev/null 2>&1; then
    tmp="$(stage_tmp "$SHARED/wallpaper-boot.jpg")"
    convert "$IMAGE" -resize '1920x1080>' "$tmp"
    commit_tmp "$tmp" "$SHARED/wallpaper-boot.jpg"
    tmp="$(stage_tmp "$SHARED/wallpaper-blur.jpg")"
    convert "$SHARED/wallpaper-boot.jpg" -blur 0x16 "$tmp"
    commit_tmp "$tmp" "$SHARED/wallpaper-blur.jpg"
else
    warn "ImageMagick not on PATH — blur/boot variants are copies"
    copy_as_jpeg "$SHARED/wallpaper.jpg" "$SHARED/wallpaper-blur.jpg"
    copy_as_jpeg "$SHARED/wallpaper.jpg" "$SHARED/wallpaper-boot.jpg"
fi

# The shared JPEG is whoever published last, often a new account's
# default.jpg. The login screen needs one readable copy per account.
session_user="${USER:-}"
if [ -z "$session_user" ] || [ "$session_user" = "root" ]; then
    session_user="$(id -un 2>/dev/null || true)"
fi
session_user="$(printf '%s' "$session_user" | tr -cd 'A-Za-z0-9._-')"
case "$session_user" in
    ""|root|.*) session_user="" ;;
esac
if [ -n "$session_user" ]; then
    mkdir -p "$SHARED/wallpapers"
    chmod a+rx "$SHARED/wallpapers" 2>/dev/null || true
    copy_as_jpeg "$IMAGE" "$SHARED/wallpapers/${session_user}.jpg" || warn "per-user wallpaper copy skipped"
    if [ -f "$SHARED/wallpaper-blur.jpg" ]; then
        tmp="$(stage_tmp "$SHARED/wallpapers/${session_user}-blur.jpg")"
        if cp "$SHARED/wallpaper-blur.jpg" "$tmp"; then
            commit_tmp "$tmp" "$SHARED/wallpapers/${session_user}-blur.jpg"
        else
            rm -f "$tmp"
        fi
    fi
fi

TOKENS="$HOME/.config/modern/tokens.json"
if [ -f "$TOKENS" ]; then
    tmp="$(stage_tmp "$SHARED/tokens.json")"
    cp "$TOKENS" "$tmp"
    commit_tmp "$tmp" "$SHARED/tokens.json"
fi

log "synced to $SHARED"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$HERE/session-chrome-sync.sh" ]; then
    bash "$HERE/session-chrome-sync.sh" || warn "chrome.json snapshot skipped"
fi
if [ -f "$HERE/session-keyboard-sync.sh" ]; then
    bash "$HERE/session-keyboard-sync.sh" || warn "keyboard.json snapshot skipped"
fi
if [ -f "$HERE/session-monitors-sync.sh" ]; then
    bash "$HERE/session-monitors-sync.sh" || warn "monitors.json snapshot skipped"
fi
if [ -f "$HERE/session-users-sync.sh" ]; then
    bash "$HERE/session-users-sync.sh" || warn "users.json snapshot skipped"
fi
