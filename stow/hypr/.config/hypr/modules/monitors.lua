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

local config = require("modules.config")

local profiles = config.value("monitors.profiles", {})

for description, p in pairs(profiles) do
    local spec = {
        output = "desc:" .. description,
        mode = p.mode or "preferred",
        position = p.position or "auto",
        scale = p.scale or 1,
        cm = p.cm or (p.hdr and "hdr" or "srgb"),
    }
    if p.vrr ~= nil then
        spec.vrr = p.vrr
    end
    if p.sdrbrightness ~= nil then
        spec.sdrbrightness = p.sdrbrightness
    end
    if p.sdrsaturation ~= nil then
        spec.sdrsaturation = p.sdrsaturation
    end
    if p.hdr then
        spec.bitdepth = 10
    end
    hl.monitor(spec)
end

-- Catch-all: SDR. HDR auto-mapping on first boot is what made the
-- shipped wallpaper look too bright/saturated on HDR panels.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb" })
