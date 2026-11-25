#!/usr/bin/env bash
# Fade one window in place around a workspace move. Source from scripts/.
# A move to or from special:background otherwise animates the window
# toward its tile on the other workspace, so it slides off to a corner.
# Fading the opacity first, then moving with no_anim, keeps it in place.
# Timing and curves match windowsIn / windowsOut in animations.lua.

window_fade_ms() {
    local root tokens cfg ms scale
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    tokens="$root/stow/hypr/.config/hypr/modules/motion_tokens.lua"
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
    ms="$(sed -n 's/^[[:space:]]*durationMediumMs[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' "$tokens" 2>/dev/null | head -n1)"
    [[ -n "$ms" ]] || ms=0
    scale=1
    if [[ -f "$cfg" ]]; then
        scale="$(jq -r '.motion.scale // 1' "$cfg" 2>/dev/null || echo 1)"
    fi
    awk -v m="$ms" -v s="$scale" 'BEGIN { v = m * s; if (v < 0) v = 0; printf "%d\n", v }'
}

window_prop_lua() {
    printf 'hl.dsp.window.set_prop({ prop = "%s", value = "%s", window = "address:%s" })' "$2" "$3" "$1"
}

window_prop() {
    hyprctl dispatch "$(window_prop_lua "$1" "$2" "$3")" >/dev/null 2>&1 || true
}

# Active and inactive opacity in one batch so both start on the same frame.
window_opacity() {
    hyprctl --batch "dispatch $(window_prop_lua "$1" opacity "$2") ; dispatch $(window_prop_lua "$1" opacity_inactive "$2")" >/dev/null 2>&1 || true
}

# fadeSwitch drives opacity changes. Speed is in ds (1ds = 100ms).
window_fade_curve() {
    local bezier="$1" ms="$2"
    hyprctl eval "hl.animation({ leaf = \"fadeSwitch\", enabled = true, speed = $(awk -v m="$ms" 'BEGIN { printf "%.2f", m / 100 }'), bezier = \"${bezier}\" })" >/dev/null 2>&1 || true
}

# Animated fade to transparent on the windowsOut curve, then freeze
# motion for the move. Waits one extra frame so the fade is not cut.
window_fade_out() {
    local addr="$1" ms
    ms="$(window_fade_ms)"
    if [[ "$ms" -gt 0 ]]; then
        window_fade_curve emphasizedAccelerate "$ms"
        window_opacity "$addr" 0
        sleep "$(awk -v m="$ms" 'BEGIN { printf "%.3f\n", (m + 20) / 1000 }')"
        window_fade_curve emphasizedDecelerate "$ms"
    fi
    window_prop "$addr" no_anim 1
}

# Transparent and frozen before the move, so nothing slides in.
window_fade_prepare_in() {
    local addr="$1"
    window_prop "$addr" no_anim 1
    window_opacity "$addr" 0
}

# Opacity 1 is the configured windows.opacity, not a fixed override.
# The fade in runs on the windowsIn curve set in animations.lua.
window_fade_finish() {
    local addr="$1"
    window_prop "$addr" no_anim unset
    window_opacity "$addr" 1
}
