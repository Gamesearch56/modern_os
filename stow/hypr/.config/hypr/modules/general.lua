-- General/decoration/misc. Window opacity is NOT design.transparency
-- (that slider is shell chrome). Rounding follows Tokens.radius.medium.
local config = require("modules.config")

local rounding = math.floor(16 * (config.value("design.cornerRounding", 1.0)))
local blur = config.value("design.blurStrength", 40)
local win_alpha = math.max(0, math.min(1, config.value("windows.opacity", 1.0)))
local gaps_in = config.value("windows.gapsIn", 5)
local gaps_out = config.value("windows.gapsOut", 10)

hl.config({
    general = {
        gaps_in = gaps_in,
        gaps_out = gaps_out,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = config.value("gaming.autoOptimize", true) ~= false,
    },
    decoration = {
        rounding = rounding,
        active_opacity = win_alpha,
        inactive_opacity = win_alpha,
        blur = {
            enabled = true,
            -- Acrylic is the only new blur that still reads as frosted
            -- material. Streaks, ripples, and cracked ice fight tonal
            -- surfaces. No chromatic fringe and no second edge radius:
            -- corners stay the rounding token. Tint comes from the
            -- surface role in theme_colors.lua.
            variant = "acrylic",
            size = math.floor(blur / 10),
            passes = 2,
            new_optimizations = true,
            acrylic = {
                aberration = 0,
                refraction = 6,
                bulb = 12,
                clarity = 0.88,
                tint = "0x00000000",
            },
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
        },
        -- A small give on move and resize. Intensity stays under
        -- the default so it does not outrun the bezier window
        -- curves. Stiffness is higher than the default 200, with
        -- damping scaled to match, so the same wobble settles
        -- sooner. Games opt out with no_wobble.
        wobble = {
            enabled = true,
            intensity = 0.1,
            stiffness = 500,
            damping = 19,
        },
    },
    dwindle = {
        preserve_split = true,
        -- Drop / Super+mouse insert follows the cursor instead of
        -- always opening on the left of the destination monitor.
        smart_split = true,
        precise_mouse_move = true,
    },
    binds = {
        window_direction_monitor_fallback = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- Greeter PATH is often too thin to see hyprland-dialog; this
        -- overlay stays for 15s and reads as a stuck login.
        disable_hyprland_guiutils_check = true,
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
