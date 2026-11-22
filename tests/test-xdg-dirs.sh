#!/usr/bin/env bash
# Locale XDG capture folders: stock English defaults follow PICTURES/VIDEOS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
FAIL=0
err() { printf 'test-xdg-dirs: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-xdg-dirs: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-xdg-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-xdg-dirs: refusing protected home" >&2; exit 1 ;;
    esac
fi

HOME="$TMP/home"
export HOME
unset XDG_CONFIG_HOME XDG_PICTURES_DIR XDG_VIDEOS_DIR
mkdir -p "$HOME/.config/modern" "$TMP/bin"

cat >"$TMP/bin/xdg-user-dir" <<'EOF'
#!/bin/sh
case "$1" in
    DOWNLOAD) printf '%s\n' "${HOME}/Downloads" ;;
    PICTURES) printf '%s\n' "${HOME}/Bilder" ;;
    VIDEOS) printf '%s\n' "${HOME}/Videos" ;;
    *) printf '%s\n' "$HOME" ;;
esac
EOF
cat >"$TMP/bin/xdg-user-dirs-update" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMP/bin/xdg-user-dir" "$TMP/bin/xdg-user-dirs-update"
export PATH="$TMP/bin:$PATH"
export LANG=de_DE.UTF-8

# shellcheck source=../scripts/lib/paths.sh
source "$ROOT/scripts/lib/paths.sh"

stock_stills="" stock_video="" locale_stills="" custom_video=""
printf -v stock_stills '%s/Pictures/Screenshots' '~'
printf -v stock_video '%s/Videos/Recordings' '~'
printf -v locale_stills '%s/Bilder/Screenshots' '~'
printf -v custom_video '%s/CustomRec' '~'

if xdg_is_stock_stills "$stock_stills" \
    && xdg_is_stock_stills "$HOME/Pictures/Screenshots" \
    && xdg_is_stock_recordings "$stock_video"; then
    ok "stock English capture paths are detected"
else
    err "stock path detection"
fi
if xdg_is_stock_stills "$locale_stills" \
    || xdg_is_stock_stills "/mnt/caps"; then
    err "locale or custom stills must not look like stock English"
else
    ok "locale and custom stills are not stock"
fi

got="$(xdg_resolve_stills "$stock_stills")"
if [ "$got" = "$HOME/Bilder/Screenshots" ]; then
    ok "stock stills resolve to XDG PICTURES"
else
    err "stills resolved to '$got'"
fi
got="$(xdg_resolve_recordings "$stock_video")"
if [ "$got" = "$HOME/Videos/Recordings" ]; then
    ok "stock recordings resolve to XDG VIDEOS"
else
    err "recordings resolved to '$got'"
fi
got="$(xdg_resolve_stills "/mnt/caps")"
if [ "$got" = "/mnt/caps" ]; then
    ok "custom stills path is left alone"
else
    err "custom stills became '$got'"
fi

printf '%s\n' '{"screenshots":{"directory":"~/Pictures/Screenshots","videoDirectory":"~/Videos/Recordings"}}' \
    >"$HOME/.config/modern/config.json"
if "$ROOT/scripts/xdg-capture-seed.sh" "$HOME/.config/modern/config.json"; then
    stills="$(jq -r '.screenshots.directory' "$HOME/.config/modern/config.json")"
    video="$(jq -r '.screenshots.videoDirectory' "$HOME/.config/modern/config.json")"
    if [ "$stills" = "$locale_stills" ] && [ "$video" = "$stock_video" ] \
        && [ -d "$HOME/Bilder/Screenshots" ] && [ -d "$HOME/Videos/Recordings" ]; then
        ok "seed rewrites stock stills to ~/Bilder/Screenshots"
    else
        err "seed wrote stills='$stills' video='$video'"
    fi
else
    err "xdg-capture-seed.sh failed"
fi

printf '%s\n' '{"screenshots":{"directory":"/mnt/caps","videoDirectory":"~/CustomRec"}}' \
    >"$HOME/.config/modern/config.json"
"$ROOT/scripts/xdg-capture-seed.sh" "$HOME/.config/modern/config.json"
stills="$(jq -r '.screenshots.directory' "$HOME/.config/modern/config.json")"
video="$(jq -r '.screenshots.videoDirectory' "$HOME/.config/modern/config.json")"
if [ "$stills" = "/mnt/caps" ] && [ "$video" = "$custom_video" ]; then
    ok "seed leaves custom capture folders alone"
else
    err "seed overwrote custom paths stills='$stills' video='$video'"
fi

mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/.local/state/modern"
printf 'wp\n' >"$HOME/Pictures/Wallpapers/keep.jpg"
printf '%s\n' "$HOME/Pictures/Wallpapers/keep.jpg" \
    >"$HOME/.local/state/modern/current-wallpaper"
"$ROOT/scripts/xdg-capture-seed.sh" "$HOME/.config/modern/config.json"
got_state="$(cat "$HOME/.local/state/modern/current-wallpaper")"
if [ -f "$HOME/Bilder/Wallpapers/keep.jpg" ] \
    && [ ! -e "$HOME/Pictures/Wallpapers/keep.jpg" ] \
    && [ "$got_state" = "$HOME/Bilder/Wallpapers/keep.jpg" ]; then
    ok "seed moves Wallpapers into XDG PICTURES"
else
    err "wallpaper migrate dest=$(ls -d "$HOME/Bilder/Wallpapers" 2>/dev/null || echo missing) state='$got_state'"
fi

listed="$("$ROOT/scripts/wallpaper-list.sh" || true)"
if printf '%s\n' "$listed" | grep -Fx "$HOME/Bilder/Wallpapers/keep.jpg" >/dev/null; then
    ok "wallpaper-list prefers XDG PICTURES/Wallpapers"
else
    err "wallpaper-list was '$listed'"
fi

if grep -F 'xdg_wallpapers_dir' "$ROOT/install/install.sh" >/dev/null \
    && grep -F 'xdg_wallpapers_dir' "$ROOT/scripts/wallpaper-fetch.sh" >/dev/null \
    && grep -F 'xdg_wallpapers_dir' "$ROOT/scripts/wallpaper-import.sh" >/dev/null \
    && grep -F 'xdg_wallpaper_library_dirs' "$ROOT/scripts/wallpaper-list.sh" >/dev/null \
    && grep -F 'xdg_wallpaper_library_dirs' "$ROOT/scripts/wallpaper-delete.sh" >/dev/null \
    && grep -F 'XdgDirs.wallpapers' "$ROOT/stow/shell/.config/quickshell/modern/Services/Wallpaper.qml" >/dev/null \
    && grep -F 'hl.dsp.focus' "$ROOT/stow/shell/.config/quickshell/modern/Services/Wallpaper.qml" >/dev/null; then
    ok "wallpaper library paths follow XDG PICTURES"
else
    err "wallpaper list/import/fetch/delete/install still hardcode Pictures"
fi

if grep -F 'xdg-capture-seed.sh' "$ROOT/install/install.sh" >/dev/null \
    && grep -F 'xdg_wallpapers_dir' "$ROOT/install/install.sh" >/dev/null \
    && grep -F 'xdg-capture-seed.sh' "$ROOT/install/system/provision-iso.sh" >/dev/null \
    && grep -F 'user_locale_lang' "$ROOT/iso/airootfs/usr/lib/modern/calamares-late.sh" >/dev/null; then
    ok "install and Calamares seed locale capture folders"
else
    err "install.sh / provision-iso / calamares-late missing XDG capture seed"
fi

[ "$FAIL" -eq 0 ]
