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

TOKENS="$HOME/.config/modern/tokens.json"
if [ -f "$TOKENS" ]; then
    tmp="$(stage_tmp "$SHARED/tokens.json")"
    cp "$TOKENS" "$tmp"
    commit_tmp "$tmp" "$SHARED/tokens.json"
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
    chrome_tmp="$(mktemp --suffix=.json -p "$SHARED" tmp.XXXXXX)"
    if jq -n \
        --argjson cfg "$(jq '{typography,design:{cornerRounding,transparency},language}' "$CFG")" \
        --argjson strings "$(jq '{
            unlock: (.session.unlock // "Unlock"),
            password: (.session.password // "Password"),
            user: (.session.user // "User"),
            signingIn: (.session.signingIn // "Signing in…"),
            authFailed: (.session.authFailed // "Could not unlock"),
            signIn: (.session.signIn // "Sign in"),
            welcome: (.session.welcome // "Welcome"),
            loginFailed: (.session.loginFailed // "Could not sign in"),
            unavailable: (.session.unavailable // "Sign-in is not available"),
            restart: (.powerMenu.restart // "Restart"),
            poweroff: (.powerMenu.poweroff // "Shut down"),
            power: (.powerMenu.title // "Power")
        }' "$trans")" \
        '$cfg + {strings: $strings}' \
        > "$chrome_tmp"
    then
        chmod a+r "$chrome_tmp" || true
        mv -f "$chrome_tmp" "$SHARED/chrome.json"
    else
        rm -f "$chrome_tmp"
        warn "chrome.json skipped"
    fi
fi

log "synced to $SHARED"
