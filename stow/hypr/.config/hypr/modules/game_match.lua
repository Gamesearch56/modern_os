-- Which windows are games: gaming.matchClass / matchTitle plus the
-- launchers and Wine helpers that share those classes. Shared by
-- games.lua (fullscreen, tearing) and mouse_windows.lua (side buttons
-- stay with the game).
local config = require("modules.config")

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
    -- Wine's own shell matches .*\\.exe. Fullscreen makes it a white
    -- sheet behind the Battle.net window. The games are other classes.
    local shell = {
        ["explorer.exe"] = true, ["wineboot.exe"] = true, ["winedevice.exe"] = true,
        ["plugplay.exe"] = true, ["rpcss.exe"] = true, ["svchost.exe"] = true,
        ["services.exe"] = true, ["conhost.exe"] = true, ["rundll32.exe"] = true,
    }
    if shell[c] then
        return true
    end
    -- Proton stamps every window in the prefix with steam_app_<id>,
    -- including explorer.exe /desktop. That host has an empty title.
    -- Fullscreening it paints a white monitor behind the launcher.
    -- A game window in the same prefix gets a real title first.
    if t == "" and c:find("^steam_app_%d+$") then
        return true
    end
    local hay = c .. "\n" .. t
    if hay:find("tradeskillmaster", 1, true) then
        return true
    end
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

return {
    class = class,
    title = title,
    excluded = excluded,
    is_game = is_game,
}
