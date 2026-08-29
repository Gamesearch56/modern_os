-- Monitor configuration, keyed on description (never a connector name
-- like DP-1 — see docs/DECISIONS.md and the portability note in
-- docs/ARCHITECTURE.md, "Monitors"). Hyprland's monitor matcher accepts
-- a "desc:<description>" output string for exactly this purpose.
--
-- config.json's monitors.profiles is a map of { "<description>": {mode,
-- position, scale, rotation, hdr, vrr} }, written by Settings > Displays'
-- drag-arrange canvas. It starts empty on a fresh install; every monitor
-- then falls through to the catch-all "preferred/auto" rule below, which
-- is exactly what makes M0 usable on any hardware without per-machine
-- edits.
--
-- Color management follows wiki.hypr.land Configuring/Basics/Monitors:
-- sdrsaturation / sdrbrightness only apply in HDR (cm=hdr, 10-bit).
-- Wide-gamut HDR OLEDs must use that path; SDR cm=srgb/dp3/edid leaves
-- sRGB samples on P3 primaries (oversaturated).

local config = require("modules.config")

local passthrough = {
    "vrr",
    "bitdepth",
    "sdrbrightness",
    "sdrsaturation",
    "sdr_eotf",
    "sdr_min_luminance",
    "sdr_max_luminance",
    "min_luminance",
    "max_luminance",
    "max_avg_luminance",
    "supports_hdr",
    "supports_wide_color",
    "icc",
}

local profiles = config.value("monitors.profiles", {})

for description, p in pairs(profiles) do
    local spec = {
        output = "desc:" .. description,
        mode = p.mode or "preferred",
        position = p.position or "auto",
        scale = p.scale or 1,
    }
    for _, key in ipairs(passthrough) do
        if p[key] ~= nil then
            spec[key] = p[key]
        end
    end
    if p.hdr then
        spec.cm = "hdr"
        if spec.bitdepth == nil then
            spec.bitdepth = 10
        end
    else
        local cm = p.cm
        if cm == "hdr" or cm == "hdredid" then
            cm = "srgb"
        end
        spec.cm = cm or "srgb"
    end
    hl.monitor(spec)
end

-- Catch-all: SDR. HDR auto-mapping on first boot is what made the
-- shipped wallpaper look too bright/saturated on HDR panels.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb" })
