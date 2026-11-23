#!/usr/bin/env bash
# The ISO bundle starts as a clone of the release pin. With --stale-bundle
# the installed desktop is this working tree instead: install/, stow/ and
# scripts/, including edits that are not committed. Ignored files stay
# out. The clone's commit stays the pin, so the installed system still
# reports that tag.

overlay_worktree_bundle() {
    local root=$1 bundle=$2 rel dest
    while IFS= read -r -d '' rel; do
        [ -n "$rel" ] || continue
        dest="$bundle/$rel"
        mkdir -p "$(dirname "$dest")"
        cp -a "$root/$rel" "$dest"
    done < <(git -C "$root" ls-files -z --cached --others --exclude-standard -- install stow scripts)
    # A file the pin still has and this tree removed must not be installed.
    while IFS= read -r -d '' rel; do
        [ -n "$rel" ] || continue
        if [ ! -e "$root/$rel" ] && [ ! -L "$root/$rel" ]; then
            rm -f "$bundle/$rel"
        fi
    done < <(git -C "$bundle" ls-files -z -- install stow scripts)
}
