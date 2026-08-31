#!/usr/bin/env bash
# Spacebar Quick Look: Dolphin selection via the copy_location QAction
# (KF6 does not export the selection over D-Bus), then Quickshell IPC.
# Not Dolphin → return; SPACE is a non-consuming bind so the focused
# field (AI chat, kitty, …) already received the key.
# Source from scripts/modern, never execute directly.

filepreview_trim() {
    printf '%s' "$1" | tr -d '[:space:]"'
}

filepreview_is_open() {
    local reply
    reply="$(qs -c modern ipc call filepreview isOpen 2>/dev/null || true)"
    [ "$(filepreview_trim "$reply")" = "true" ]
}

filepreview_class_is_dolphin() {
    local class="$1"
    case "$class" in
        org.kde.dolphin | org.kde.dolphin-* | dolphin | dolphin-*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

filepreview_uri_to_path() {
    python3 -c '
import sys, urllib.parse
p = sys.argv[1].strip().splitlines()[0].strip() if len(sys.argv) > 1 else ""
if p.startswith("file://"):
    p = urllib.parse.unquote(p[7:])
    if not p.startswith("/"):
        p = "/" + p
print(p)
' "$1"
}

filepreview_restore_clipboard() {
    local old="$1"
    if [ -n "$old" ]; then
        printf '%s' "$old" | wl-copy 2>/dev/null || true
    else
        wl-copy --clear 2>/dev/null || true
    fi
}

filepreview_dolphin_dest() {
    local pid="$1"
    if busctl --user status "org.kde.dolphin-${pid}" >/dev/null 2>&1; then
        printf '%s\n' "org.kde.dolphin-${pid}"
        return 0
    fi
    busctl --user list 2>/dev/null | awk '$1 ~ /dolphin/ { print $1; exit }'
}

filepreview_copy_location() {
    local dest="$1"
    busctl --user call "$dest" /dolphin/Dolphin_1/actions/copy_location \
        org.qtproject.Qt.QAction resetEnabled >/dev/null 2>&1 || true
    busctl --user call "$dest" /dolphin/Dolphin_1/actions/copy_location \
        org.qtproject.Qt.QAction trigger >/dev/null 2>&1
}

filepreview_wait_path() {
    local i p
    for i in 1 2 3 4 5 6 7 8; do
        p="$(wl-paste -n -t text 2>/dev/null || true)"
        p="$(filepreview_uri_to_path "$p")"
        if [ -n "$p" ] && [ "$p" != " " ] && [ -e "$p" ]; then
            printf '%s\n' "$p"
            return 0
        fi
        sleep 0.03
    done
    return 1
}

filepreview_selection() {
    local pid="$1"
    local dest old path
    dest="$(filepreview_dolphin_dest "$pid")"
    [ -n "$dest" ] || return 1
    old="$(wl-paste -n 2>/dev/null || true)"
    printf ' ' | wl-copy 2>/dev/null || true
    if ! filepreview_copy_location "$dest"; then
        filepreview_restore_clipboard "$old"
        return 1
    fi
    if path="$(filepreview_wait_path)"; then
        filepreview_restore_clipboard "$old"
        printf '%s\n' "$path"
        return 0
    fi
    filepreview_restore_clipboard "$old"
    return 1
}

filepreview_run() {
    if filepreview_is_open; then
        qs -c modern ipc call filepreview hide >/dev/null 2>&1 || true
        return 0
    fi

    local json class pid path
    json="$(hyprctl activewindow -j 2>/dev/null || true)"
    class="$(printf '%s' "$json" | jq -r '.class // empty' 2>/dev/null || true)"
    pid="$(printf '%s' "$json" | jq -r '.pid // empty' 2>/dev/null || true)"

    if filepreview_class_is_dolphin "$class"; then
        if path="$(filepreview_selection "$pid")" && [ -n "$path" ]; then
            qs -c modern ipc call filepreview open "$path" >/dev/null 2>&1 || true
            return 0
        fi
        qs -c modern ipc call notifications toast "$(t filePreview.noSelection)" "" >/dev/null 2>&1 || true
        return 0
    fi
}
