-- Power button and lid switch. Actions come from config.json
-- (Settings → Energy). The bind is stable; modern power reads the
-- current value so a Settings change does not need a compositor reload.

local paths = require("modules.paths")
local modern = paths.modern
local locked = { locked = true }

hl.bind("XF86PowerOff", hl.dsp.exec_cmd(modern .. " power button"), locked)
hl.bind("XF86PowerDown", hl.dsp.exec_cmd(modern .. " power button"), locked)

-- Lid close is bindl in hyprlang; Lua bind with locked covers the lid
-- while the session is locked. Open restores DPMS.
pcall(function()
    hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(modern .. " power lid"), locked)
end)
pcall(function()
    hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl dispatch dpms on"), locked)
end)
