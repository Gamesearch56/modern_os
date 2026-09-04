#!/usr/bin/env bash
# Stow wrapper with non-destructive conflict handling. Source, never
# execute directly. Fixes the audited bug where the old install.sh's
# "desktop" package silently wiped every .desktop file on each run: we
# never delete anything, we move conflicts to a timestamped backup
# directory and log exactly what moved.
#
# Conflict detection walks the package tree. A path is a real conflict
# when it exists as a regular file or as a symlink that does *not*
# already resolve inside this package (another GNU Stow tree, e.g. a
# previous dotfiles repo). Ours we leave. `--no-folding` keeps every
# stowed path a direct symlink so re-runs stay idempotent.

STOW_DIR="${STOW_DIR:-$REPO_ROOT/stow}"

_stow_ours() {
    local path="$1"
    local pkg_resolved="$2"
    local resolved
    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    [ -n "$resolved" ] && [ -n "$pkg_resolved" ] || return 1
    case "$resolved" in
        "$pkg_resolved"|"$pkg_resolved"/*) return 0 ;;
    esac
    return 1
}

# Bash walk instead of find(1): some environments hide .config trees from find.
_stow_walk() {
    local d="$1" f
    for f in "$d"/* "$d"/.[!.]*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        if [ -d "$f" ] && [ ! -L "$f" ]; then
            _stow_walk "$f"
        else
            printf '%s\0' "$f"
        fi
    done
}

_stow_backup_existing() {
    local pkg="$1"
    local pkg_dir="$2"
    local target="$3"
    local backup_root="$4"
    local backup_dir=""
    local src rel dest cur ancestor pkg_resolved target_slash

    pkg_resolved="$(readlink -f "$pkg_dir")"
    target="$(readlink -f "$target")"
    target_slash="${target}/"

    _backup() {
        local from="$1"
        local rel_path="${from#"$target_slash"}"
        [ "$from" != "$target" ] || return 0
        [ -e "$from" ] || [ -L "$from" ] || return 0
        if [ -z "$backup_dir" ]; then
            backup_dir="$backup_root/$(date +%Y%m%d-%H%M%S)/$pkg"
            run mkdir -p "$backup_dir"
            log_warn "Conflicts for '$pkg', backing up to $backup_dir:"
        fi
        run mkdir -p "$(dirname "$backup_dir/$rel_path")"
        log_warn "  backing up $from"
        run mv "$from" "$backup_dir/$rel_path"
    }

    while IFS= read -r -d '' src; do
        rel="${src#"$pkg_dir"/}"
        dest="$target/$rel"
        cur="$dest"
        while [ -n "$cur" ] && [ "$cur" != "$target" ] && [ "$cur" != "/" ]; do
            if [ -L "$cur" ]; then
                if _stow_ours "$cur" "$pkg_resolved"; then
                    break
                fi
                _backup "$cur"
                break
            fi
            ancestor="$(dirname "$cur")"
            [ "$ancestor" = "$cur" ] && break
            cur="$ancestor"
        done
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        _stow_ours "$dest" "$pkg_resolved" && continue
        [ -L "$dest" ] && continue
        _backup "$dest"
    done < <(_stow_walk "$pkg_dir")
}

stow_package() {
    local pkg="$1"
    local target="${2:-$HOME}"
    local pkg_dir="$STOW_DIR/$pkg"
    # Backups stay under the *target* home so a --target run from another
    # account never writes into the invoking user's $HOME.
    local backup_root="${STOW_BACKUP_ROOT:-$target/.local/state/modern/stow-backups}"

    [ -d "$pkg_dir" ] || { log_warn "stow package '$pkg' not found at $pkg_dir, skipping"; return 0; }

    log_info "Stowing '$pkg' -> $target"
    _stow_backup_existing "$pkg" "$pkg_dir" "$target" "$backup_root"

    local stow_out=""
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        run bash -c "cd '$STOW_DIR' && stow --no-folding -t '$target' '$pkg'"
    elif ! stow_out="$(cd "$STOW_DIR" && stow --no-folding -t "$target" "$pkg" 2>&1)"; then
        log_error "stow '$pkg' failed:"
        printf '%s\n' "$stow_out" | tee -a "${LOG_FILE:-/dev/null}" >&2
        die "stow of '$pkg' aborted — leftover regular files in $target? See above."
    fi
    [ -n "$stow_out" ] && log_info "$stow_out"
    log_ok "Stowed '$pkg'"
}

unstow_package() {
    local pkg="$1"
    local target="${2:-$HOME}"
    log_info "Unstowing '$pkg' from $target"
    run bash -c "cd '$STOW_DIR' && stow --no-folding -D -t '$target' '$pkg'"
}
