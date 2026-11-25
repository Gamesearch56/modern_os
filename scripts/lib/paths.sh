#!/usr/bin/env bash
# Tilde paths from config.json and locale XDG user dirs. Source from
# scripts/, never execute. Build the ~/ prefix without a quoted '~/'
# literal (SC2088). A bare ${var#~/} tilde-expands the pattern to $HOME/.

expand_home() {
    local p="${1:-}"
    local prefix
    printf -v prefix '%s/' '~'
    if [ "$p" = "~" ]; then
        printf '%s\n' "$HOME"
        return
    fi
    if [ "${p#"$prefix"}" != "$p" ]; then
        printf '%s/%s\n' "$HOME" "${p#"$prefix"}"
        return
    fi
    printf '%s\n' "$p"
}

xdg_tilde() {
    local p="${1:-}" prefix
    printf -v prefix '%s/' '~'
    if [ "$p" = "$HOME" ]; then
        printf '%s\n' '~'
        return
    fi
    if [ "${p#"$HOME"/}" != "$p" ]; then
        printf '%s%s\n' "$prefix" "${p#"$HOME"/}"
        return
    fi
    printf '%s\n' "$p"
}

xdg_locale_lang() {
    local conf="${MODERN_LOCALE_CONF:-/etc/locale.conf}" line
    if [ -n "${LANG:-}" ]; then
        printf '%s\n' "$LANG"
        return
    fi
    if [ -f "$conf" ]; then
        line="$(sed -nE "s/^[[:space:]]*LANG=[\"']?([^\"'[:space:]]+).*/\1/p" "$conf" | head -1)"
        if [ -n "$line" ]; then
            printf '%s\n' "$line"
            return
        fi
    fi
    printf '%s\n' "C.UTF-8"
}

xdg_ensure_user_dirs() {
    local lang
    lang="$(xdg_locale_lang)"
    if command -v xdg-user-dirs-update >/dev/null 2>&1; then
        env LANG="$lang" LC_MESSAGES="$lang" xdg-user-dirs-update >/dev/null 2>&1 || true
    fi
}

xdg_user_dir() {
    local key="$1" fallback="$2" got="" dirs line
    if command -v xdg-user-dir >/dev/null 2>&1; then
        got="$(xdg-user-dir "$key" 2>/dev/null || true)"
    fi
    if [ -z "$got" ] || [ "$got" = "$HOME" ]; then
        dirs="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
        if [ -f "$dirs" ]; then
            line="$(sed -nE "s/^XDG_${key}_DIR=\"?([^\"]*)\"?.*/\1/p" "$dirs" | head -1)"
            line="${line//\$HOME/$HOME}"
            line="${line//\$\{HOME\}/$HOME}"
            got="$line"
        fi
    fi
    if [ -n "$got" ] && [ "$got" != "$HOME" ]; then
        printf '%s\n' "$got"
        return
    fi
    printf '%s/%s\n' "$HOME" "$fallback"
}

xdg_is_stock_stills() {
    local stock
    printf -v stock '%s/Pictures/Screenshots' '~'
    case "${1:-}" in
        "" | "$stock" | "$HOME/Pictures/Screenshots") return 0 ;;
    esac
    return 1
}

xdg_is_stock_recordings() {
    local stock
    printf -v stock '%s/Videos/Recordings' '~'
    case "${1:-}" in
        "" | "$stock" | "$HOME/Videos/Recordings") return 0 ;;
    esac
    return 1
}

xdg_resolve_stills() {
    local raw="${1:-}" expanded
    expanded="$(expand_home "$raw")"
    if xdg_is_stock_stills "$raw" || xdg_is_stock_stills "$expanded"; then
        printf '%s/Screenshots\n' "$(xdg_user_dir PICTURES Pictures)"
        return
    fi
    printf '%s\n' "$expanded"
}

xdg_resolve_recordings() {
    local raw="${1:-}" expanded
    expanded="$(expand_home "$raw")"
    if xdg_is_stock_recordings "$raw" || xdg_is_stock_recordings "$expanded"; then
        printf '%s/Recordings\n' "$(xdg_user_dir VIDEOS Videos)"
        return
    fi
    printf '%s\n' "$expanded"
}

xdg_wallpapers_dir() {
    printf '%s/Wallpapers\n' "$(xdg_user_dir PICTURES Pictures)"
}

xdg_wallpaper_library_dirs() {
    local lib pic
    lib="$(xdg_wallpapers_dir)"
    pic="$(xdg_user_dir PICTURES Pictures)"
    printf '%s\n' "$lib"
    [ "$pic/Wallpaper" = "$lib" ] || printf '%s\n' "$pic/Wallpaper"
    [ "$HOME/Pictures/Wallpapers" = "$lib" ] || printf '%s\n' "$HOME/Pictures/Wallpapers"
    if [ "$HOME/Pictures/Wallpaper" != "$lib" ] && [ "$HOME/Pictures/Wallpaper" != "$pic/Wallpaper" ]; then
        printf '%s\n' "$HOME/Pictures/Wallpaper"
    fi
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/modern/wallpapers"
}

# English ~/Pictures/Wallpapers from older installs. Skip when XDG
# PICTURES is already that folder (English locale).
xdg_legacy_wallpaper_dirs() {
    local dest src
    dest="$(xdg_wallpapers_dir)"
    for src in "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Wallpaper"; do
        [ -d "$src" ] || continue
        if [ "$src" != "$dest" ]; then
            printf '%s\n' "$src"
        fi
    done
}

xdg_migrate_wallpapers() {
    local dest src f base state cur new
    dest="$(xdg_wallpapers_dir)"
    mkdir -p "$dest"
    while IFS= read -r src; do
        [ -d "$src" ] || continue
        for f in "$src"/*; do
            [ -f "$f" ] || continue
            case "${f,,}" in
                *.jpg|*.jpeg|*.png|*.webp) ;;
                *) continue ;;
            esac
            base="$(basename "$f")"
            mv -f -- "$f" "$dest/$base"
        done
        rmdir "$src" 2>/dev/null || true
    done < <(xdg_legacy_wallpaper_dirs || true)

    state="${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper"
    [ -f "$state" ] || return 0
    cur="$(tr -d '\n' <"$state")"
    [ -n "$cur" ] || return 0
    case "$cur" in
        "$HOME/Pictures/Wallpapers"/*|"$HOME/Pictures/Wallpaper"/*)
            new="$dest/$(basename "$cur")"
            if [ -f "$new" ]; then
                printf '%s\n' "$new" >"$state"
            fi
            ;;
    esac
}
