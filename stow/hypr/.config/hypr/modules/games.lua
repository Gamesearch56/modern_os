-- Game windows get tearing and exclusive fullscreen. Other clients keep
-- vsync, blur, and animations. Java titles such as Project Zomboid rename
-- after map, so fullscreen is dispatched once from open/class/title and
-- never re-applied — a static rule would pin SUPER+F.
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

-- window.title has a 50ms budget. Lua patterns backtrack on a long
-- Files title, so match literals and .* in plain text and cap the length.
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
    -- Files renames the window while it opens. That is not a game,
    -- and the title callback cannot afford a second look.
    if c:find("nautilus", 1, true) or c:find("thunar", 1, true)
        or c:find("dolphin", 1, true) or c:find("nemo", 1, true) then
        return true
    end
    -- Battle.net Agent / updater helpers — not games.
    if c == "agent.exe" or c:find("agent%.exe", 1, false) then
        return true
    end
    -- Battle.net launcher (not World of Warcraft / Warcraft III): keep windowed.
    local hay = c .. "\n" .. t
    if hay:find("battle%.net", 1, false) or hay:find("battlenet", 1, true)
        or hay:find("blizzard battle", 1, true) then
        if not hay:find("warcraft", 1, true) then
            return true
        end
    end
    return false
end

-- Titles Proton/XWayland often set without a matching *.exe class.
local function blizzard_game_title(t)
    if type(t) ~= "string" or t == "" then
        return false
    end
    local low = string.lower(t)
    if low:find("world of warcraft", 1, true) then
        return true
    end
    if low:find("warcraft iii", 1, true) or low:find("warcraft 3", 1, true) then
        return true
    end
    if low:find("diablo", 1, true) or low:find("overwatch", 1, true) then
        return true
    end
    if low:find("hearthstone", 1, true) or low:find("starcraft", 1, true) then
        return true
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
    if blizzard_game_title(w.title) or blizzard_game_title(w.initial_title) then
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
    -- Handlers outlive reload. Re-read fullscreen at most once a second
    -- so a title storm does not decode config.json inside the 50ms budget.
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

local function addr_of(w)
    if not w then
        return ""
    end
    return tostring(w.address or "")
end

local function force_fs(w)
    if not w or excluded(w) or not auto_fs_on() or not is_game(w) then
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
