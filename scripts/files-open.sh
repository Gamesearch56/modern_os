#!/usr/bin/env bash
# Open one file with the default application from Settings / mimeapps.
# An empty text editor, image viewer, or video player uses
# install/manifests/default-apps.json. A launch override in that file
# (one argv) replaces modern-launch for that desktop id.
# MODERN_OPEN_ASSUME_EXEC=1 skips the executable check so a test can
# print the override when the binary is not installed.
set -euo pipefail

_open_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install/lib/default-apps.sh
source "$_open_root/install/lib/default-apps.sh"
unset _open_root

print_only=0
can_only=0
if [[ "${1:-}" == "--print" ]]; then
    print_only=1
    shift
elif [[ "${1:-}" == "--can" ]]; then
    # Exit 0 when a handler exists. Do not launch, and do not record it.
    can_only=1
    shift
fi

path="${1:-}"
if [[ -z "$path" || "$path" != /* ]]; then
    echo "files-open: need a file path" >&2
    exit 2
fi
if [[ ! -e "$path" ]]; then
    echo "files-open: missing" >&2
    exit 1
fi

launch() {
    if [[ "$print_only" -eq 1 ]]; then
        printf '%q\n' "$@"
        exit 0
    fi
    # Remember the file before the viewer replaces this process.
    local here err
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if ! err="$("$here/files-places.sh" record "$path" 2>&1 >/dev/null)"; then
        printf 'files-open: recent list was not updated: %s\n' "${err:-refused}" >&2
    fi
    exec "$@"
}

config="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"

role_desktop() {
    local role="$1" id
    [[ -f "$config" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    id="$(jq -r --arg k "$role" '.apps.defaults[$k] // empty' "$config" 2>/dev/null || true)"
    [[ -n "$id" && "$id" != "null" ]] || return 0
    printf '%s\n' "$id"
}

mime="$(xdg-mime query filetype "$path" 2>/dev/null || true)"
desktop=""
role=""
# Settings → Applications owns these kinds. A browser or an old player
# often sits first in mimeapps.list; that answer must not beat the
# viewer the user picked (an empty role is the shipped app).
case "$mime" in
    image/*) role="imageViewer" ;;
    video/*|audio/*) role="videoPlayer" ;;
    text/html|application/xhtml+xml) ;;
    text/*|application/json|application/xml|application/javascript|application/x-shellscript|inode/x-empty)
        role="textEditor"
        ;;
esac
if [[ -z "$role" ]]; then
    case "${path##*.}" in
        png|jpg|jpeg|gif|webp|bmp|svg|avif|jxl|tif|tiff|heif|heic|qoi) role="imageViewer" ;;
        mp4|mkv|webm|avi|mov|m4v|mp3|flac|ogg|opus|wav) role="videoPlayer" ;;
        txt|md|json|xml|sh|py|lua|qml|conf|ini|log|csv) role="textEditor" ;;
    esac
fi
if [[ -n "$role" ]]; then
    desktop="$(role_desktop "$role" || true)"
    if [[ -z "$desktop" ]]; then
        desktop="$(default_app_desktop "$role" || true)"
    fi
elif [[ -n "$mime" ]]; then
    desktop="$(xdg-mime query default "$mime" 2>/dev/null || true)"
fi
desktop="${desktop%.desktop}"

override=()
if [[ -n "$desktop" ]]; then
    mapfile -t override < <(default_app_exec_for_desktop "$desktop" || true)
fi
app_ready() {
    local id="$1" one
    [[ -n "$id" ]] || return 1
    if [[ ${#override[@]} -gt 0 ]]; then
        if [[ "${MODERN_OPEN_ASSUME_EXEC:-}" == 1 || -x "${override[0]}" ]]; then
            return 0
        fi
    fi
    for one in \
        "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${id}.desktop" \
        /usr/local/share/applications/"${id}.desktop" \
        /usr/share/applications/"${id}.desktop"
    do
        [[ -f "$one" ]] && return 0
    done
    return 1
}

if [[ "$can_only" -eq 1 ]]; then
    if app_ready "$desktop"; then
        exit 0
    fi
    exit 1
fi

if [[ ${#override[@]} -gt 0 ]]; then
    if [[ "${MODERN_OPEN_ASSUME_EXEC:-}" == 1 || -x "${override[0]}" ]]; then
        launch "${override[@]}" "$path"
    fi
fi

if [[ -n "$desktop" ]]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    launch "$dir/modern-launch" "$desktop" "$path"
fi

launch xdg-open "$path"
