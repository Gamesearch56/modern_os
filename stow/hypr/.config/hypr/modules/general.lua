-- General/decoration/misc. Window opacity is NOT design.transparency
-- (that slider is shell chrome). Rounding follows Tokens.radius.medium.
local config = require("modules.config")

-- A virtual display paints Hyprland's acrylic blur, FP16 buffer, and
-- color-management pass as solid black. Transparent shell surfaces (the
-- bar strip, a widget popup, image viewers) then cover the desktop.
-- NVIDIA, AMD, and Intel keep the frosted path, including when a
-- leftover simple-framebuffer card sits beside the real GPU.
local real_vendor = {
    ["0x10de"] = true, -- NVIDIA
    ["0x1002"] = true, -- AMD
    ["0x8086"] = true, -- Intel
}
local virtual_vendor = {
    ["0x1af4"] = true, -- Red Hat virtio
    ["0x1234"] = true, -- QEMU / Bochs
    ["0x1b36"] = true, -- QXL
    ["0x15ad"] = true, -- VMware
    ["0x80ee"] = true, -- VirtualBox
    ["0x1414"] = true, -- Hyper-V
}

local function slurp(path)
    local f = io.open(path, "r")
    if not f then
        return ""
    end
    local raw = f:read("*a") or ""
    f:close()
    return raw:lower()
end

local function virtual_driver(text)
    return text:find("virtio", 1, true) or text:find("qxl", 1, true)
        or text:find("vmwgfx", 1, true) or text:find("bochs", 1, true)
        or text:find("vbox", 1, true) or text:find("hyperv", 1, true)
        or text:find("virgl", 1, true) or text:find("vkms", 1, true)
end

local function simple_fb(text)
    return text:find("simple-framebuffer", 1, true) or text:find("simpledrm", 1, true)
        or text:find("ramfb", 1, true)
end

local function virtual_gpu()
    local real, virt, simple = false, false, false
    for i = 0, 15 do
        local base = "/sys/class/drm/card" .. i
        local vendor = (slurp(base .. "/device/vendor"):gsub("%s+", ""))
        local uevent = slurp(base .. "/device/uevent")
        if vendor ~= "" or uevent ~= "" then
            if real_vendor[vendor] then
                real = true
            end
            if virtual_vendor[vendor] or virtual_driver(uevent) then
                virt = true
            elseif simple_fb(uevent) then
                simple = true
            end
        end
    end
    -- A passed-through desktop GPU wins over the hypervisor flag and
    -- over a firmware framebuffer that is still registered.
    if real then
        return false
    end
    if virt or simple then
        return true
    end
    return slurp("/proc/cpuinfo"):find("hypervisor", 1, true) ~= nil
end

local soft = virtual_gpu()
if soft then
    hl.env("MODERN_SOFTWARE_GPU", "1")
    -- Virtio's GLES path drops the alpha channel. The software scene
    -- graph writes a real ARGB buffer, so the bar and popups stay
    -- see-through instead of covering the desktop.
    hl.env("QSG_RHI_BACKEND", "software")
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
            new_optimizations = not soft,
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
        -- Focusing the normal workspace dismisses special:background.
        -- The parked windows stay on it.
        hide_special_on_workspace_change = true,
    },
    -- Opening the background workspace must not warp the pointer onto
    -- another monitor before the matching toggle closes it.
    cursor = {
        warp_on_toggle_special = 0,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- Greeter PATH is often too thin to see hyprland-dialog; this
        -- overlay stays for 15s and reads as a stuck login.
        disable_hyprland_guiutils_check = true,
        -- An update reloads the shell; a reload or crash while locked
        -- must let the new shell take the lock back (Services/Session).
        allow_session_lock_restore = true,
    },
    -- A system update that ships a newer Hyprland otherwise opens
    -- hyprland-update-screen ("Hyprland has been updated").
    ecosystem = {
        no_update_news = true,
    },
    render = {
        cm_auto_hdr = 0,
        -- Both default on. On a virtual GPU their shaders replace any
        -- translucent layer with black; a desktop GPU is left as shipped.
        cm_enabled = not soft,
        use_fp16 = soft and 0 or 2,
    },
})

if hl.layer_rule then
    if soft then
        hl.layer_rule({
            name = "quickshell-noblur",
            match = { namespace = "quickshell" },
            blur = false,
        })
    else
        hl.layer_rule({
            name = "quickshell-blur",
            match = { namespace = "quickshell" },
            blur = true,
            ignore_alpha = 0.2,
        })
    end
end
