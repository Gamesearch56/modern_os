#!/usr/bin/env bash
# Stow wrapper with non-destructive conflict handling. Source, never
# execute directly. Fixes the audited bug where the old install.sh's
# "desktop" package silently wiped every .desktop file on each run: we
# never delete anything, we move conflicts to a timestamped backup
# directory and log exactly what moved.

STOW_DIR="${STOW_DIR:-$REPO_ROOT/stow}"

stow_package() {
    local pkg="$1"
    local target="${2:-$HOME}"
    local pkg_dir="$STOW_DIR/$pkg"
    # Backups stay under the *target* home so a --target /home/devuser run
    # from another account never writes into the daily-driver $HOME.
    local backup_root="${STOW_BACKUP_ROOT:-$target/.local/state/modern/stow-backups}"

    [ -d "$pkg_dir" ] || { log_warn "stow package '$pkg' not found at $pkg_dir, skipping"; return 0; }

    log_info "Stowing '$pkg' -> $target"

    # Dry-run stow first to detect conflicts without touching anything.
    local conflicts
    conflicts="$(cd "$STOW_DIR" && stow -n -t "$target" "$pkg" 2>&1 | grep -E '^\s*\*' || true)"

    if [ -n "$conflicts" ]; then
        local backup_dir="$backup_root/$(date +%Y%m%d-%H%M%S)/$pkg"
        run mkdir -p "$backup_dir"
        log_warn "Conflicts for '$pkg', backing up to $backup_dir:"
        while IFS= read -r line; do
            # stow -n conflict lines look like: "  * existing target is neither a link nor a directory: .config/foo"
            local rel="${line##*: }"
            [ -e "$target/$rel" ] || continue
            local dest="$backup_dir/$rel"
            run mkdir -p "$(dirname "$dest")"
            log_warn "  backing up $target/$rel"
            run mv "$target/$rel" "$dest"
        done <<< "$conflicts"
    fi

    run bash -c "cd '$STOW_DIR' && stow -t '$target' '$pkg'"
    log_ok "Stowed '$pkg'"
}

unstow_package() {
    local pkg="$1"
    local target="${2:-$HOME}"
    log_info "Unstowing '$pkg' from $target"
    run bash -c "cd '$STOW_DIR' && stow -D -t '$target' '$pkg'"
}
