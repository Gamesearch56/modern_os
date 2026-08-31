#!/usr/bin/env bash
# Tilde paths from config.json. Source from scripts/, never execute.
# ${var#~/} tilde-expands the pattern to $HOME/, so
# "$HOME/${DIR#~/}" becomes $HOME/~/Pictures/... — quote a literal prefix.

expand_home() {
    local p="${1:-}"
    local prefix='~/'
    case "$p" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${p#"$prefix"}"
            ;;
        *)
            printf '%s\n' "$p"
            ;;
    esac
}
