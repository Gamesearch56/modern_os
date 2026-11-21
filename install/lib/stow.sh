#!/usr/bin/env bash
# Stow wrapper with non-destructive conflict handling. Source, never
# execute directly. Never deletes anything: a conflict moves to a
# timestamped backup directory and every move is logged.
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
    _stow_prune "$pkg_dir" "$pkg_dir" "$target"
    log_ok "Stowed '$pkg'"
}

# A file dropped from a package leaves a dangling link in every home it was
# stowed into; a stale .desktop link would still shadow the system entry.
# Only broken links that point back into this package are removed.
_stow_prune() {
    local dir="$1" pkg_dir="$2" target="$3"
    local rel="${dir#"$pkg_dir"}" pkg_resolved link f
    pkg_resolved="$(readlink -f "$pkg_dir")"
    for link in "$target$rel"/* "$target$rel"/.[!.]*; do
        [ -L "$link" ] && [ ! -e "$link" ] || continue
        case "$(readlink -m "$link")" in
            "$pkg_resolved"/*)
                log_info "Removing stale link $link"
                run rm -f "$link"
                ;;
        esac
    done
    for f in "$dir"/* "$dir"/.[!.]*; do
        [ -d "$f" ] && [ ! -L "$f" ] && _stow_prune "$f" "$pkg_dir" "$target"
    done
    return 0
}

# Packages that left the repo, with the folder their links lived in. Once
# the package is gone nothing stows it again, so _stow_prune never visits
# those links; only broken ones pointing into the old package go, and the
# user's own files there stay.
STOW_RETIRED=("imv:.config/imv" "mpv:.config/mpv")

stow_retire() {
    local target="${1:-$HOME}"
    local stow_resolved entry pkg dir link
    stow_resolved="$(readlink -m "$STOW_DIR")"
    for entry in "${STOW_RETIRED[@]}"; do
        pkg="${entry%%:*}"
        dir="$target/${entry#*:}"
        [ -d "$dir" ] && [ ! -L "$dir" ] || continue
        while IFS= read -r -d '' link; do
            [ -L "$link" ] && [ ! -e "$link" ] || continue
            case "$(readlink -m "$link")" in
                "$stow_resolved/$pkg"/*)
                    log_info "Removing retired link $link"
                    run rm -f "$link"
                    ;;
            esac
        done < <(_stow_walk "$dir")
    done
    return 0
}

unstow_package() {
    local pkg="$1"
    local target="${2:-$HOME}"
    log_info "Unstowing '$pkg' from $target"
    run bash -c "cd '$STOW_DIR' && stow --no-folding -D -t '$target' '$pkg'"
}
