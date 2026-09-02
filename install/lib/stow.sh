#!/usr/bin/env bash
# Stow wrapper with non-destructive conflict handling. Source, never
# execute directly. Fixes the audited bug where the old install.sh's
# "desktop" package silently wiped every .desktop file on each run: we
# never delete anything, we move conflicts to a timestamped backup
# directory and log exactly what moved.
#
# Conflict detection walks the package tree. A path is a real conflict
# only when it exists as a regular file (e.g. /etc/skel/.bashrc) that
# does *not* already resolve inside this package. GNU Stow directory
# folding makes `.config/hypr/hyprland.lua` look like a regular file
# even when `.config/hypr` is a symlink into stow/ — moving those would
# pull files out of the git clone. `--no-folding` keeps every stowed
# path a direct symlink so re-runs stay idempotent.

STOW_DIR="${STOW_DIR:-$REPO_ROOT/stow}"

_stow_backup_existing() {
    local pkg="$1"
    local pkg_dir="$2"
    local target="$3"
    local backup_root="$4"
    local backup_dir=""
    local src rel dest resolved pkg_resolved

    pkg_resolved="$(readlink -f "$pkg_dir")"

    while IFS= read -r -d '' src; do
        rel="${src#"$pkg_dir"/}"
        dest="$target/$rel"
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        # Direct symlink: already stowed (or a user link we leave alone).
        [ -L "$dest" ] && continue
        resolved="$(readlink -f "$dest" 2>/dev/null || true)"
        if [ -n "$resolved" ] && [ -n "$pkg_resolved" ]; then
            case "$resolved" in
                "$pkg_resolved"|"$pkg_resolved"/*) continue ;;
            esac
        fi
        if [ -z "$backup_dir" ]; then
            backup_dir="$backup_root/$(date +%Y%m%d-%H%M%S)/$pkg"
            run mkdir -p "$backup_dir"
            log_warn "Conflicts for '$pkg', backing up to $backup_dir:"
        fi
        run mkdir -p "$(dirname "$backup_dir/$rel")"
        log_warn "  backing up $dest"
        run mv "$dest" "$backup_dir/$rel"
    done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type l \) -print0)
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
