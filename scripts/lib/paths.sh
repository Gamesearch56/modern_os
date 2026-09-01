#!/usr/bin/env bash
# Tilde paths from config.json. Source from scripts/, never execute.
# Build the ~/ prefix without a quoted '~/' literal (SC2088). A bare
# ${var#~/} tilde-expands the pattern to $HOME/.

expand_home() {
    local p="${1:-}"
    local prefix
    printf -v prefix '%s/' '~'
    if [ "$p" = "~" ]; then
        printf '%s\n' "$HOME"
        return
    fi
    if [ "${p#"$prefix"}" != "$p" ]; then
        printf '%s/%s\n' "$HOME" "${p#"$prefix"}"
        return
    fi
    printf '%s\n' "$p"
}
