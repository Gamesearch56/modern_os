-- Game windows: tearing, and fullscreen when the title asks for it.
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
    "steam_app_.*|gamescope|.*\\.exe|ProjectZomboid.*|projectzomboid|LWJGL|lwjgl|wow|Wow|Warcraft.*")
local title = config.value("gaming.matchTitle",
    ".*\\.exe|Project Zomboid|World of Warcraft|Warcraft III|Warcraft 3|Diablo.*|Overwatch.*|Hearthstone|StarCraft.*|Call of Duty.*")

local MAX_ID = 240

local function compile_alt(alt)
    if #alt > MAX_ID then
        return nil
    end
    local parts = {}
    local buf = {}
    local i = 1
    local function flush()
        if #buf > 0 then
            parts[#parts + 1] = table.concat(buf)
            buf = {}
        end
    end
    while i <= #alt do
        if alt:sub(i, i + 1) == ".*" then
            flush()
            parts[#parts + 1] = false
            i = i + 2
        elseif alt:sub(i, i) == "\\" and i < #alt then
            buf[#buf + 1] = alt:sub(i + 1, i + 1)
            i = i + 2
        else
            buf[#buf + 1] = alt:sub(i, i)
            i = i + 1
        end
    end
    flush()
    return parts
end

local function compile_spec(spec)
    local compiled = {}
    if type(spec) ~= "string" or spec == "" then
        return compiled
    end
    for alt in string.gmatch(spec .. "|", "([^|]*)|") do
        if alt ~= "" and #compiled < 32 then
            local parts = compile_alt(alt)
            if parts then
                compiled[#compiled + 1] = parts
            end
        end
    end
    return compiled
end

local function match_parts(value, parts)
    local pos, i, n = 1, 1, #parts
    while i <= n do
        local part = parts[i]
        if part == false then
            repeat
                i = i + 1
            until i > n or parts[i] ~= false
            if i > n then
                return true
            end
            part = parts[i]
            if i == n then
                local start = #value - #part + 1
                return start >= pos and value:sub(start) == part
            end
            local at = value:find(part, pos, true)
            if not at then
                return false
            end
            pos = at + #part
        else
            if value:sub(pos, pos + #part - 1) ~= part then
                return false
            end
            pos = pos + #part
        end
        i = i + 1
    end
    return pos == #value + 1
end

local function matches_compiled(value, compiled)
    if type(value) ~= "string" or value == "" or #value > MAX_ID then
        return false
    end
    for i = 1, #compiled do
        if match_parts(value, compiled[i]) then
            return true
        end
    end
    return false
end

local class_pats = compile_spec(class)
local title_pats = compile_spec(title)

local function ident(v)
    if type(v) ~= "string" or #v > MAX_ID then
        return ""
    end
    return string.lower(v)
end

local function excluded(w)
    local c = ident(w.class or w.initial_class)
    local t = ident(w.title or w.initial_title)
    if c == "steam" or c == "lutris" or c == "zenity" then
        return true
    end
    if c:find("heroic", 1, true) or c:find("steamwebhelper", 1, true) then
        return true
    end
    if c:find("nautilus", 1, true) or c:find("thunar", 1, true)
        or c:find("dolphin", 1, true) or c:find("nemo", 1, true) then
        return true
    end
    if c == "agent.exe" or c:find("agent%.exe", 1, false) then
        return true
    end
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
    if matches_compiled(w.class, class_pats) or matches_compiled(w.initial_class, class_pats) then
        return true
    end
    if matches_compiled(w.title, title_pats) or matches_compiled(w.initial_title, title_pats) then
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
        rule.no_wobble = true
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

local fs_on = true
local fs_sec = -1

local function auto_fs_on()
    local now = os.time()
    if now == fs_sec then
        return fs_on
    end
    fs_sec = now
    if config.invalidate then
        config.invalidate()
    end
    fs_on = config.value("gaming.autoFullscreen", true) ~= false
    return fs_on
end

local done = {}
local armed = {}

local function addr_of(w)
    if not w then
        return ""
    end
    return tostring(w.address or "")
end

local function fs_of(w)
    return tonumber(w and w.fullscreen) or 0
end

local function dispatch_fs(w)
    if not (hl.dispatch and hl.dsp and hl.dsp.window and hl.dsp.window.fullscreen_state) then
        return
    end
    local addr = addr_of(w)
    local spec = { internal = 2, client = 2, action = "set", window = w }
    local ok = pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state(spec))
    end)
    if not ok and addr ~= "" then
        spec.window = "address:" .. addr
        pcall(function()
            hl.dispatch(hl.dsp.window.fullscreen_state(spec))
        end)
    end
end

local function consider(w)
    if not w or excluded(w) or not auto_fs_on() or not is_game(w) then
        return
    end
    local addr = addr_of(w)
    if addr == "" or done[addr] then
        return
    end
    if fs_of(w) >= 1 then
        done[addr] = true
        return
    end
    if armed[addr] then
        return
    end
    armed[addr] = true
    dispatch_fs(w)
    if not hl.timer then
        done[addr] = true
        return
    end
    hl.timer(function()
        if done[addr] then
            return
        end
        local fs = 0
        pcall(function()
            fs = fs_of(w)
        end)
        if fs >= 1 then
            done[addr] = true
            return
        end
        pcall(function()
            if excluded(w) or not is_game(w) or not auto_fs_on() then
                done[addr] = true
                return
            end
            dispatch_fs(w)
        end)
        done[addr] = true
    end, { timeout = 500, type = "oneshot" })
end

if hl.on then
    hl.on("window.open_early", consider)
    hl.on("window.open", consider)
    hl.on("window.class", consider)
    hl.on("window.title", consider)
    hl.on("window.fullscreen", consider)
    hl.on("window.close", function(w)
        local a = addr_of(w)
        if a ~= "" then
            done[a] = nil
            armed[a] = nil
        end
    end)
end
