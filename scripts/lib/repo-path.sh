#!/usr/bin/env bash
# Resolve the clone path. Source, never execute.
# Order: $MODERN_REPO, ~/.config/modern/repo, $HOME/modern_dotfile.
modern_repo_path() {
    if [ -n "${MODERN_REPO:-}" ]; then
        printf '%s\n' "$MODERN_REPO"
        return 0
    fi
    local f="${XDG_CONFIG_HOME:-$HOME/.config}/modern/repo"
    if [ -f "$f" ]; then
        local line=""
        IFS= read -r line <"$f" || true
        if [ -n "${line:-}" ]; then
            printf '%s\n' "$line"
            return 0
        fi
    fi
    printf '%s\n' "${HOME}/modern_dotfile"
}
