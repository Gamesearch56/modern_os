-- Detect Steam/Proton/gamescope/Wine games and apply per-window
-- compositor hints. Other clients keep vsync, blur, and animations.
-- Tearing only fires on windows with `immediate` (wiki Tearing page).
local config = require("modules.config")

local function on(path, fallback)
    local v = config.value(path, fallback)
    return v ~= false
end

local auto_fs = on("gaming.autoFullscreen", true)
local auto_opt = on("gaming.autoOptimize", true)
if not auto_fs and not auto_opt then
    return
end

local class = config.value("gaming.matchClass", "steam_app_.*|gamescope|.*\\.exe")
local title = config.value("gaming.matchTitle", ".*\\.exe")

local function effects(name, match)
    local rule = { name = name, match = match }
    if auto_fs then
        rule.fullscreen = true
        rule.sync_fullscreen = true
    end
    if auto_opt then
        rule.immediate = true
        rule.no_blur = true
        rule.no_shadow = true
        rule.no_anim = true
        rule.opaque = true
        rule.content = "game"
        rule.idle_inhibit = "fullscreen"
    end
    return rule
end

if type(class) == "string" and class ~= "" then
    hl.window_rule(effects("modern-game-class", { class = class }))
end
if type(title) == "string" and title ~= "" then
    hl.window_rule(effects("modern-game-exe", { title = title, xwayland = true }))
end
