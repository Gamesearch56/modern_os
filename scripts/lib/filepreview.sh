#!/usr/bin/env bash
# Spacebar in Nautilus is GNOME Sushi (windowrules.lua). This script
# must not steal it. Overlay already open: hide. Source from
# scripts/modern, never execute.
filepreview_trim() {
    printf '%s' "$1" | tr -d '[:space:]"'
}

filepreview_is_open() {
    local reply
    reply="$(qs -c modern ipc call filepreview isOpen 2>/dev/null || true)"
    [ "$(filepreview_trim "$reply")" = "true" ]
}

filepreview_class_is_nautilus() {
    local class="$1"
    case "$class" in
        org.gnome.Nautilus | org.gnome.Nautilus-* | org.gnome.nautilus | nautilus | nautilus-*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

filepreview_class_is_preview() {
    local class="$1"
    local title="$2"
    case "$class" in
        modern.quicklook | modern.filepreview)
            return 0
            ;;
    esac
    case "$title" in
        modern.filepreview | modern.quicklook)
            return 0
            ;;
    esac
    return 1
}

filepreview_run() {
    local lock="${XDG_RUNTIME_DIR:-/tmp}/modern-filepreview.lock"
    exec 9>"$lock"
    flock -n 9 || return 0

    local json class title
    json="$(hyprctl activewindow -j 2>/dev/null || true)"
    class="$(printf '%s' "$json" | jq -r '.class // empty' 2>/dev/null || true)"
    title="$(printf '%s' "$json" | jq -r '.title // empty' 2>/dev/null || true)"

    if filepreview_class_is_nautilus "$class"; then
        return 0
    fi

    if filepreview_is_open || filepreview_class_is_preview "$class" "$title"; then
        qs -c modern ipc call filepreview hide >/dev/null 2>&1 || true
        return 0
    fi
}
