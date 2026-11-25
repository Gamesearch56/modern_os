#!/usr/bin/env bash
# Small interactive helpers. Source, never execute directly. Every prompt
# respects $ASSUME_YES so install.sh --yes / CI can run non-interactively.

ASSUME_YES="${ASSUME_YES:-0}"
DRY_RUN="${DRY_RUN:-0}"

confirm() {
    local prompt="$1"
    if [ "$ASSUME_YES" -eq 1 ]; then
        return 0
    fi
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

run() {
    # Wraps a command so --dry-run prints instead of executing.
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '\033[90m[dry-run]\033[0m %s\n' "$*"
        return 0
    fi
    "$@"
}

progress() {
    printf '  \033[90m->\033[0m %s\n' "$*"
}
