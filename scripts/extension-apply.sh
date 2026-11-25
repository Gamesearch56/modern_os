#!/usr/bin/env bash
# Turn ~/.local/share/modern/extensions into a shell overlay.
# The folder mirrors repository paths. Only the shell and Hyprland
# trees are accepted. Nothing here writes into the modern_os clone:
# the overlay is a directory of symlinks under the state dir.
#
#   extension-apply.sh overlay     print the overlay path, or nothing
#   extension-apply.sh hypr-path   print the Hyprland override directory
# A missing folder is success with no output. An unsafe folder fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repo-path.sh
source "$SCRIPT_DIR/lib/repo-path.sh"

SHELL_REL="stow/shell/.config/quickshell/modern"
HYPR_REL="stow/hypr/.config/hypr"

die() { printf 'extension-apply: %s\n' "$*" >&2; exit 1; }

extension_root() {
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/modern/extensions"
}

# Intermediate directories of the two trees, plus the files under them.
allowed_rel() {
    case "$1" in
        stow | stow/shell | stow/shell/.config | stow/shell/.config/quickshell \
            | stow/shell/.config/quickshell/modern \
            | stow/hypr | stow/hypr/.config | stow/hypr/.config/hypr)
            return 0
            ;;
        stow/shell/.config/quickshell/modern/* | stow/hypr/.config/hypr/*)
            return 0
            ;;
    esac
    return 1
}

# Absent is fine. Present must be owned by this account, not writable
# by anyone else, and contain only real files inside the two trees.
extension_guard() {
    local root="$1"
    [ -d "$root" ] || return 0
    [ ! -L "$root" ] || die "the extensions folder is a symlink"
    local uid mode group other
    uid="$(stat -c '%u' "$root")"
    [ "$uid" = "$(id -u)" ] || die "the extensions folder is not owned by this account"
    mode="$(stat -c '%a' "$root")"
    group=$(( (10#$mode / 10) % 10 ))
    other=$(( 10#$mode % 10 ))
    if [ $((group & 2)) -ne 0 ] || [ $((other & 2)) -ne 0 ]; then
        die "the extensions folder is writable by someone else"
    fi
    local root_real p rel real
    root_real="$(readlink -f "$root")"
    while IFS= read -r -d '' p; do
        [ ! -L "$p" ] || die "refusing a symlink in the extensions folder"
        rel="${p#"$root"/}"
        case "$rel" in
            *..*) die "refusing a path that leaves the extensions folder" ;;
        esac
        allowed_rel "$rel" || die "refusing a path outside the shell and Hyprland trees"
        real="$(readlink -f "$p")"
        case "$real" in
            "$root_real" | "$root_real"/*) ;;
            *) die "refusing a path that leaves the extensions folder" ;;
        esac
    done < <(find -P "$root" -mindepth 1 -print0 2>/dev/null || true)
}

has_file() {
    local dir="$1" p
    [ -d "$dir" ] || return 1
    while IFS= read -r -d '' p; do
        [ -f "$p" ] && return 0
    done < <(find -P "$dir" -type f -print0 2>/dev/null || true)
    return 1
}

overlay_dir() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/modern/shell-overlay"
    case "$state" in
        */modern/shell-overlay) printf '%s\n' "$state" ;;
        *) die "refusing to build an overlay outside the state directory" ;;
    esac
}

# One symlink per shipped file. The user's file wins when the same
# relative path exists. Link names live in the state dir; the clone
# is only a link target.
build_overlay() {
    local root="$1" dest="$2" shipped="$3"
    rm -rf -- "$dest"
    mkdir -p -- "$dest"
    local p rel over parent
    while IFS= read -r -d '' p; do
        rel="${p#"$shipped"/}"
        parent="$(dirname -- "$rel")"
        mkdir -p -- "$dest/$parent"
        over="$root/$SHELL_REL/$rel"
        if [ -f "$over" ] && [ ! -L "$over" ]; then
            ln -s -- "$over" "$dest/$rel"
        else
            ln -s -- "$p" "$dest/$rel"
        fi
    done < <(find -P "$shipped" -type f -print0)
    [ -d "$root/$SHELL_REL" ] || return 0
    while IFS= read -r -d '' p; do
        rel="${p#"$root/$SHELL_REL"/}"
        [ -e "$dest/$rel" ] && continue
        parent="$(dirname -- "$rel")"
        mkdir -p -- "$dest/$parent"
        ln -s -- "$p" "$dest/$rel"
    done < <(find -P "$root/$SHELL_REL" -type f -print0)
}

cmd_overlay() {
    local root
    root="$(extension_root)"
    [ -d "$root" ] || return 0
    extension_guard "$root"
    has_file "$root/$SHELL_REL" || return 0
    local repo shipped dest
    repo="$(modern_repo_path)"
    shipped="$repo/$SHELL_REL"
    [ -d "$shipped" ] || die "the shipped shell is not in the repository"
    dest="$(overlay_dir)"
    build_overlay "$root" "$dest" "$shipped"
    printf '%s\n' "$dest"
}

cmd_hypr() {
    local root
    root="$(extension_root)"
    [ -d "$root" ] || return 0
    extension_guard "$root"
    has_file "$root/$HYPR_REL" || return 0
    printf '%s\n' "$root/$HYPR_REL"
}

case "${1:-overlay}" in
    overlay) cmd_overlay ;;
    hypr-path) cmd_hypr ;;
    *) die "usage: extension-apply.sh overlay|hypr-path" ;;
esac
