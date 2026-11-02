-- Window/workspace animation curves, derived from the same motion tokens
-- the QML shell uses (see docs/MOTION.md) so window motion and shell
-- motion read as one system rather than two.
--
-- hl.curve(name, { type = "bezier", points = {{x0,y0},{x1,y1}} }) defines
-- a cubic bezier from its two configurable inner control points.
-- hl.animation({ leaf, enabled, speed, bezier, style }) applies one to an
-- animation tree leaf. speed is in ds (1ds = 100ms).

local tokens = require("modules.motion_tokens")
local config = require("modules.config")

local scale = config.value("motion.scale", 1.0)
local function speed(ms)
    return (ms * scale) / 100.0
end

for name, points in pairs(tokens.bezier) do
    hl.curve(name, { type = "bezier", points = { { points[1], points[2] }, { points[3], points[4] } } })
end

if scale <= 0 then
    -- motion.scale = 0 means "off" — disable every animation leaf rather
    -- than animating at 0 speed, which some leaves reject.
    hl.animation({ leaf = "global", enabled = false })
else
    hl.animation({ leaf = "windows", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasized" })
    -- popin 92% matches Motion.overlayScale(false); overlay enter/exit
    -- both use medium, not a snappier windowsOut.
    hl.animation({ leaf = "windowsIn", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasizedDecelerate", style = "popin 92%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasizedAccelerate", style = "popin 92%" })
    -- Super+arrows swap/resize; short so the wobble does not linger.
    hl.animation({ leaf = "windowsMove", enabled = true, speed = speed(tokens.durationShortMs), bezier = "emphasized" })
    hl.animation({ leaf = "border", enabled = true, speed = speed(tokens.durationShortMs), bezier = "standard" })
    hl.animation({ leaf = "fade", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasized" })
    -- Opacity changes. Background apps fade in and out with this instead
    -- of moving, so it uses the windowsIn curve. scripts/lib/window-fade.sh
    -- swaps in the windowsOut curve for the fade out, then restores this.
    hl.animation({ leaf = "fadeSwitch", enabled = true, speed = speed(tokens.durationMediumMs), bezier = "emphasizedDecelerate" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = speed(tokens.durationLongMs), bezier = "emphasizedDecelerate", style = "slide" })
    -- Off: mapping autostart clients onto special:background must not flash
    -- a vertical slide of the app on login.
    hl.animation({ leaf = "specialWorkspace", enabled = false })
end
