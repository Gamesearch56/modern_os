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
SHARED="/var/lib/modern/session"

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

copy_as_jpeg() {
    local src="$1" dest="$2"
    if command -v magick >/dev/null 2>&1; then
        magick "$src" "$dest"
    elif command -v convert >/dev/null 2>&1; then
        convert "$src" "$dest"
    else
        cp "$src" "$dest"
    fi
}

copy_as_jpeg "$IMAGE" "$SHARED/wallpaper.jpg"

if command -v magick >/dev/null 2>&1; then
    magick "$IMAGE" -resize '1920x1080>' "$SHARED/wallpaper-boot.jpg"
    magick "$SHARED/wallpaper-boot.jpg" -blur 0x16 "$SHARED/wallpaper-blur.jpg"
elif command -v convert >/dev/null 2>&1; then
    convert "$IMAGE" -resize '1920x1080>' "$SHARED/wallpaper-boot.jpg"
    convert "$SHARED/wallpaper-boot.jpg" -blur 0x16 "$SHARED/wallpaper-blur.jpg"
else
    warn "ImageMagick not on PATH — blur/boot variants are copies"
    cp "$SHARED/wallpaper.jpg" "$SHARED/wallpaper-blur.jpg"
    cp "$SHARED/wallpaper.jpg" "$SHARED/wallpaper-boot.jpg"
fi

TOKENS="$HOME/.config/modern/tokens.json"
if [ -f "$TOKENS" ]; then
    cp "$TOKENS" "$SHARED/tokens.json"
fi

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
TRANSLATIONS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/translations"
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
    # Keyed on the shipped files, so adding a translation needs no edit here
    # and an unknown language.ui renders English instead of the QML literals.
    lang="$(jq -r '.language.ui // "en"' "$CFG")"
    lang="${lang//[!a-z]/}"
    trans="$TRANSLATIONS/$lang.json"
    [ -f "$trans" ] || trans="$TRANSLATIONS/en.json"
    jq -n \
        --argjson cfg "$(jq '{typography,design:{cornerRounding,transparency},language}' "$CFG")" \
        --arg unlock "$(jq -r '.session.unlock // "Unlock"' "$trans")" \
        --arg password "$(jq -r '.session.password // "Password"' "$trans")" \
        --arg user "$(jq -r '.session.user // "User"' "$trans")" \
        '$cfg + {strings:{unlock:$unlock, password:$password, user:$user}}' \
        > "$SHARED/chrome.json" || warn "chrome.json skipped"
fi

log "synced to $SHARED"
