-- General/decoration/misc config, sourced from config.json's "design"
-- block (see Settings > Windows in docs/ARCHITECTURE.md). Border colors
-- live in modules/colors.lua, not here — kept separate so theme-apply.sh
-- can regenerate just the color file without touching this one.

local config = require("modules.config")

local rounding = math.floor(8 * (config.value("design.cornerRounding", 1.0)))
local blur = config.value("design.blurStrength", 40)
local alpha = config.value("design.transparency", 0.85)

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },
    decoration = {
        rounding = rounding,
        active_opacity = alpha,
        inactive_opacity = alpha * 0.92,
        blur = {
            enabled = true,
            size = math.floor(blur / 10),
            passes = 2,
            new_optimizations = true,
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
    -- Keep the desktop in SDR until Settings > Displays opts into HDR.
    -- Hyprland 0.55+ auto-HDR on wide-gamut panels maps SDR wallpapers
    -- (and the bar) as if they were PQ, which looks blown-out / neon.
    render = {
        cm_auto_hdr = 0,
    },
})
