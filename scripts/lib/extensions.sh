# shellcheck shell=bash
# Launch prefix for a process that should see extension files.
# EXT_PREFIX and EXT_WARN are the result the caller reads.
# shellcheck disable=SC2034
# EXT_PREFIX is empty when the user has no extensions, so the command
# that follows is the same one an unmodded session runs.
# A missing extensions directory returns immediately: no scan, no
# bubblewrap, no extra process.

extension_prefix() {
    EXT_PREFIX=()
    EXT_WARN=""
    local ext="${XDG_DATA_HOME:-$HOME/.local/share}/modern/extensions"
    [ -d "$ext" ] || return 0
    local apply errdir out="" rc=0
    apply="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/extension-apply.sh"
    errdir="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
    mkdir -p "$errdir" 2>/dev/null || true
    out="$("$apply" overlay 2>"$errdir/extensions.err")" || rc=$?
    if [ "$rc" -ne 0 ]; then
        EXT_WARN="extensions were refused; starting the stock files"
        return 0
    fi
    [ -n "$out" ] || return 0
    local bwrap="${MODERN_BWRAP:-bwrap}"
    if ! command -v "$bwrap" >/dev/null 2>&1; then
        EXT_WARN="bubblewrap is missing; starting without the shell overlay"
        return 0
    fi
    local config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/modern"
    [ -d "$config" ] || {
        EXT_WARN="the shell config is missing; starting without the shell overlay"
        return 0
    }
    EXT_PREFIX=("$bwrap" --dev-bind / / --bind "$out" "$config" --)
}
