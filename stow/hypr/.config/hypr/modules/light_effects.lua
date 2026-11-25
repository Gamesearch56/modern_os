-- Settings -> Gaming -> Performance ("drop effects for speed"). On a weak
-- iGPU blur, shadows and the wobble mesh cost more frame time than the
-- rest of the desktop together, so this one switch drops them everywhere.
-- Commons/Chrome.lightEffects mirrors it for the shell surfaces.
local config = require("modules.config")

return config.value("gaming.autoOptimize", false) == true
