#!/usr/bin/env bash
# One-shot Nautilus view prefs (icon grid + size caption) and the
# sidebar places from this desktop (Downloads, Pictures, Videos).
# Colors come from gtk.css / Papirus-Dark via theme-apply.sh, not here.
# Space preview is GNOME Sushi via sushi-previewer.sh (muted media overlay).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bookmarks_only=0
if [ "${1:-}" = "--bookmarks-only" ]; then
    bookmarks_only=1
fi

# gtk-3.0/bookmarks is gitignored — a clone never ships a username.
# Expand XDG dirs for the target $HOME so any install gets the same
# sidebar.
seed_bookmarks() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks"
    local key path label
    if [ -L "$dest" ]; then
        rm -f "$dest"
    fi
    if [ -e "$dest" ]; then
        return 0
    fi
    if command -v xdg-user-dirs-update >/dev/null 2>&1; then
        xdg-user-dirs-update >/dev/null 2>&1 || true
    fi
    mkdir -p "$(dirname "$dest")"
    : >"$dest"
    for key in DOWNLOAD PICTURES VIDEOS; do
        if command -v xdg-user-dir >/dev/null 2>&1; then
            path="$(xdg-user-dir "$key")"
        else
            case "$key" in
                DOWNLOAD) path="$HOME/Downloads" ;;
                PICTURES) path="$HOME/Pictures" ;;
                VIDEOS) path="$HOME/Videos" ;;
            esac
        fi
        [ -n "$path" ] || continue
        [ "$path" != "$HOME" ] || continue
        mkdir -p "$path"
        label="$(basename "$path")"
        printf 'file://%s %s\n' "$path" "$label" >>"$dest"
    done
}

# Nautilus's "No Home Directory" dialog is not $HOME. Startup checks
# that ~/.config/nautilus is a real directory (g_file_test IS_DIR). A
# leftover stow symlink into a removed clone fails that check every launch.
ensure_config_dir() {
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/nautilus"
    if [ -L "$dir" ] && [ ! -e "$dir" ]; then
        rm -f "$dir"
    elif [ -e "$dir" ] && [ ! -d "$dir" ]; then
        rm -f "$dir"
    fi
    mkdir -p "$dir"
}

if [ "$bookmarks_only" -eq 0 ]; then
    previewer="${SCRIPT_DIR}/sushi-previewer.sh"
    previewer_dir="${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services"
    mkdir -p "$previewer_dir"
    rm -f "${previewer_dir}/org.gnome.NautilusPreviewer2.service"
    if [ -x "$previewer" ] && [ -x /usr/lib/org.gnome.NautilusPreviewer ]; then
        printf '%s\n' "[D-BUS Service]" "Name=org.gnome.NautilusPreviewer" \
            "Exec=${previewer}" \
            >"${previewer_dir}/org.gnome.NautilusPreviewer.service"
    else
        rm -f "${previewer_dir}/org.gnome.NautilusPreviewer.service"
    fi

    if command -v gsettings >/dev/null 2>&1 \
        && gsettings list-schemas 2>/dev/null | grep -qx org.gnome.nautilus.preferences; then
        gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view' >/dev/null 2>&1 || true
        gsettings set org.gnome.nautilus.icon-view captions "['size', 'none', 'none']" >/dev/null 2>&1 || true
    fi
fi

ensure_config_dir
seed_bookmarks

