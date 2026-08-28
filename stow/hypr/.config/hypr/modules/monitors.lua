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
    hl.monitor({
        output = "desc:" .. description,
        mode = p.mode or "preferred",
        position = p.position or "auto",
        scale = p.scale or 1,
    })
end

-- Catch-all for any monitor not covered by a saved profile — never leave
-- a display unconfigured, which is what produced the old setup's
-- hardcoded DP-1/DP-2 brittleness.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
