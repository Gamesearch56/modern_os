-- General/decoration/misc. Window opacity is NOT design.transparency
-- (that slider is shell chrome). Rounding follows Tokens.radius.medium.
local config = require("modules.config")

local rounding = math.floor(16 * (config.value("design.cornerRounding", 1.0)))
local blur = config.value("design.blurStrength", 40)
local win_alpha = config.value("windows.opacity", 1.0)
local gaps_in = config.value("windows.gapsIn", 5)
local gaps_out = config.value("windows.gapsOut", 10)

hl.config({
    general = {
        gaps_in = gaps_in,
        gaps_out = gaps_out,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },
    decoration = {
        rounding = rounding,
        active_opacity = win_alpha,
        inactive_opacity = math.min(1, win_alpha * 0.98),
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
    render = {
        cm_auto_hdr = 0,
    },
})

if hl.layer_rule then
    hl.layer_rule({
        name = "quickshell-blur",
        match = { namespace = "quickshell" },
        blur = true,
        ignore_alpha = 0.2,
    })
end
