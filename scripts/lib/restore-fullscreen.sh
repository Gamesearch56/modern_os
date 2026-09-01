# shellcheck shell=bash
# Re-apply exclusive fullscreen after a UI/shell reload. Hyprland and
# the bar exclusive zone can drop xdg-fullscreen (YouTube, movies) so
# the bar sits on the video until the user toggles fullscreen again.
# Source from scripts/; never execute.

_fs_list=""

_fs_clients() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0
    hyprctl clients -j 2>/dev/null | jq -r '
        .[] | select(
            (.fullscreen == 2 or .fullscreen == 3 or .fullscreen == true)
            or (.fullscreenClient == 2 or .fullscreenClient == 3)
        ) | .address
    ' | grep -v '^$' || true
}

fs_save() {
    _fs_list="$(_fs_clients)"
}

_fs_apply() {
    local addr="$1"
    [ -n "$addr" ] || return 0
    hyprctl dispatch "hl.dsp.window.fullscreen_state({internal=2, client=2, action=\"set\", window=\"address:${addr}\"})" \
        >/dev/null 2>&1 || true
}

fs_restore() {
    local addr
    [ -n "${_fs_list:-}" ] || return 0
    command -v hyprctl >/dev/null 2>&1 || return 0
    while IFS= read -r addr; do
        _fs_apply "$addr"
    done <<< "$_fs_list"
}
