-- Detect Steam/Proton/gamescope/Wine/native games and apply per-window
-- compositor hints. Other clients keep vsync, blur, and animations.
-- Tearing only fires on windows with `immediate` (wiki Tearing page).
--
-- fullscreen / fullscreen_state are *static* effects: Hyprland evaluates
-- them once against initialClass/initialTitle, and they also pin the
-- window so SUPER+F cannot leave exclusive mode. Java/LWJGL titles such
-- as Project Zomboid map tiled, then rename after boot. Dispatch
-- exclusive fullscreen from open/class/title once; do not re-apply.
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

local class = config.value("gaming.matchClass",
    "steam_app_.*|gamescope|.*\\.exe|ProjectZomboid.*|projectzomboid|LWJGL|lwjgl")
local title = config.value("gaming.matchTitle", ".*\\.exe|Project Zomboid")

local function magic(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

-- RE2 alts from config.json (literals + .* + \.) → Lua patterns.
local function re2_alt(alt)
    local parts = {}
    local buf = ""
    local i = 1
    local function flush()
        if buf ~= "" then
            parts[#parts + 1] = magic(buf)
            buf = ""
        end
    end
    while i <= #alt do
        if alt:sub(i, i + 1) == ".*" then
            flush()
            parts[#parts + 1] = ".*"
            i = i + 2
        elseif alt:sub(i, i) == "\\" and i < #alt then
            buf = buf .. alt:sub(i + 1, i + 1)
            i = i + 2
        else
            buf = buf .. alt:sub(i, i)
            i = i + 1
        end
    end
    flush()
    return "^" .. table.concat(parts) .. "$"
end

local function matches_spec(value, spec)
    if type(value) ~= "string" or value == "" or type(spec) ~= "string" or spec == "" then
        return false
    end
    for alt in string.gmatch(spec .. "|", "([^|]*)|") do
        if alt ~= "" and value:find(re2_alt(alt)) then
            return true
        end
    end
    return false
end

local function excluded(w)
    local c = string.lower(tostring(w.class or w.initial_class or ""))
    local t = string.lower(tostring(w.title or w.initial_title or ""))
    if c == "steam" or c == "lutris" or c == "zenity" then
        return true
    end
    if c:find("heroic", 1, true) or c:find("steamwebhelper", 1, true) then
        return true
    end
    -- Battle.net launcher (not World of Warcraft): keep windowed.
    local hay = c .. "\n" .. t
    if hay:find("battle%.net", 1, false) or hay:find("battlenet", 1, true)
        or hay:find("blizzard battle", 1, true) then
        if not hay:find("warcraft", 1, true) then
            return true
        end
    end
    return false
end

local function is_game(w)
    if not w or excluded(w) then
        return false
    end
    if matches_spec(w.class, class) or matches_spec(w.initial_class, class) then
        return true
    end
    if matches_spec(w.title, title) or matches_spec(w.initial_title, title) then
        return true
    end
    return false
end

local function effects(name, match)
    local rule = { name = name, match = match }
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
    hl.window_rule(effects("modern-game-initial-class", { initial_class = class }))
end
if type(title) == "string" and title ~= "" then
    hl.window_rule(effects("modern-game-title", { title = title }))
end

local function auto_fs_on()
    -- Event handlers outlive a config reload (same as hyprland.start).
    -- Re-read the file so Settings → Gaming → fullscreen off actually
    -- stops forcing exclusive fullscreen.
    if config.invalidate then
        config.invalidate()
    end
    return config.value("gaming.autoFullscreen", true) ~= false
end

local done = {}

local function addr_of(w)
    if not w then
        return ""
    end
    return tostring(w.address or "")
end

local function force_fs(w)
    if not auto_fs_on() or not w or not is_game(w) then
        return
    end
    local addr = addr_of(w)
    if addr == "" then
        return
    end
    local fs = tonumber(w.fullscreen) or 0
    if fs >= 2 then
        done[addr] = true
        return
    end
    -- Already applied once (or the user Super+F'd out). Do not pin
    -- exclusive fullscreen with a static rule — that makes toggle a no-op.
    if done[addr] then
        return
    end
    if not (hl.dispatch and hl.dsp and hl.dsp.window and hl.dsp.window.fullscreen_state) then
        return
    end
    local spec = { internal = 2, client = 2, action = "set", window = w }
    local ok = pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state(spec))
    end)
    if not ok and w.address then
        spec.window = "address:" .. addr
        pcall(function()
            hl.dispatch(hl.dsp.window.fullscreen_state(spec))
        end)
    end
end

if hl.on then
    hl.on("window.open_early", force_fs)
    hl.on("window.open", force_fs)
    hl.on("window.class", force_fs)
    hl.on("window.title", force_fs)
    hl.on("window.close", function(w)
        local a = addr_of(w)
        if a ~= "" then
            done[a] = nil
        end
    end)
end
