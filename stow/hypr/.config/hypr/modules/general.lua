-- General/decoration/misc. Window opacity is NOT design.transparency
-- (that slider is shell chrome). Rounding follows Tokens.radius.medium.
local config = require("modules.config")

-- virtio, qxl, vmware, and bochs paint the acrylic shader as solid
-- black. The bar strip, imv, and the capture overlay are transparent,
-- so a virtual display goes black while a real GPU stays frosted.
local function virtual_gpu()
    for i = 0, 7 do
        local f = io.open("/sys/class/drm/card" .. i .. "/device/uevent", "r")
        if f then
            local raw = (f:read("*a") or ""):lower()
            f:close()
            if raw:find("virtio", 1, true) or raw:find("qxl", 1, true)
                or raw:find("vmwgfx", 1, true) or raw:find("bochs", 1, true)
                or raw:find("vboxvideo", 1, true) or raw:find("hyperv", 1, true) then
                return true
            end
        end
    end
    return false
end

local soft = virtual_gpu()
if soft then
    hl.env("MODERN_SOFTWARE_GPU", "1")
end

local rounding = math.floor(16 * (config.value("design.cornerRounding", 1.0)))
local blur = config.value("design.blurStrength", 40)
local win_alpha = math.max(0, math.min(1, config.value("windows.opacity", 1.0)))
local gaps_in = config.value("windows.gapsIn", 5)
local gaps_out = config.value("windows.gapsOut", 10)

hl.config({
    general = {
        gaps_in = gaps_in,
        gaps_out = gaps_out,
        border_size = 1,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = config.value("gaming.autoOptimize", true) ~= false,
    },
    decoration = {
        rounding = rounding,
        active_opacity = win_alpha,
        inactive_opacity = win_alpha,
        blur = {
            enabled = not soft,
            -- Acrylic is the only new blur that still reads as frosted
            -- material. Streaks, ripples, and cracked ice fight tonal
            -- surfaces. Bulb/refraction draw a lit glass rim that
            -- fights MD3 hairline outline + tonal elevation; frost
            -- stays in the surface. Tint comes from theme_colors.lua.
            variant = "acrylic",
            size = math.floor(blur / 10),
            passes = 2,
            new_optimizations = true,
            acrylic = {
                aberration = 0,
                refraction = 0,
                -- Values below 4 are treated as unset and snap to the
                -- 48px default rim. 4px is the floor that still applies.
                bulb = 4,
                clarity = 0.88,
                tint = "0x00000000",
            },
        },
        -- Elevation level 2: Tokens.elevation shadowRadius 6 at 10%
        -- black. Color is applied from the shadow role in theme_colors.
        shadow = {
            enabled = true,
            range = 6,
            render_power = 3,
        },
        -- A light give on move and resize. Intensity is well under
        -- the 0.2 default so the mesh does not look jelly-like.
        -- Stiffness stays high so swaps settle quickly; extra damping
        -- cuts the bounce. Games opt out with no_wobble.
        wobble = {
            enabled = true,
            intensity = 0.05,
            stiffness = 800,
            damping = 40,
        },
    },
    dwindle = {
        preserve_split = true,
        -- Side-by-side while the tile is wider than it is tall, because
        -- these panels are landscape. Once a column would be narrower
        -- than it is tall, the next window stacks. smart_split follows
        -- the cursor triangle and stacks a wide tile whenever the
        -- pointer sits in its top or bottom half.
        -- Dragging a window still inserts toward the cursor.
        split_width_multiplier = 1.0,
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

if hl.layer_rule and not soft then
    hl.layer_rule({
        name = "quickshell-blur",
        match = { namespace = "quickshell" },
        blur = true,
        ignore_alpha = 0.2,
    })
end
