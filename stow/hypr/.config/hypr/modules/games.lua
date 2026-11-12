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
local yielded = {}
local covered = {}
local tries = {}

local function addr_of(w)
    if not w then
        return ""
    end
    return tostring(w.address or "")
end

-- Mode 2 covers the screen. Mode 1 is maximized: a windowed-fullscreen
-- game (WoW Forever's GxMaximize) asks for that, and the bar stays up.
-- w.fullscreen is Hyprland's mode; fullscreen_client is the game's.
local function mode_num(v)
    local n = tonumber(v)
    if n then
        return n
    end
    if v == true then
        return 2
    end
    return 0
end

local function fs_of(w)
    if not w then
        return 0
    end
    local v = mode_num(w.fullscreen)
    if v == 0 and w.fullscreen == nil then
        v = mode_num(w.fullscreen_client)
    end
    return v
end

-- Borderless games stay at client mode 1. Telling them they are
-- exclusive makes them drop back to a tile. Cover the screen instead.
local function dispatch_fs(w)
    if not (hl.dispatch and hl.dsp and hl.dsp.window and hl.dsp.window.fullscreen_state) then
        return
    end
    local addr = addr_of(w)
    local client = mode_num(w.fullscreen_client)
    if client < 1 then
        client = 2
    end
    local spec = { internal = 2, client = client, action = "set", window = w }
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

-- Declared below. consider() runs only from timers, after this is set.
local workspace_name

-- Another exclusive game already owns the workspace (its login or a
-- dialog). A maximized game is not that owner: mode 1 still shows the bar.
local function other_game_holds(w)
    local ws = w.workspace
    if not (ws and ws.has_fullscreen == true) or fs_of(w) >= 1 then
        return false
    end
    local holder = ws.fullscreen_window
    if not holder or addr_of(holder) == "" or addr_of(holder) == addr_of(w) then
        return false
    end
    return is_game(holder) and fs_of(holder) >= 2
end

local function consider(w)
    if not w or excluded(w) or not auto_fs_on() or not is_game(w) then
        return
    end
    local addr = addr_of(w)
    if addr == "" or done[addr] then
        return
    end
    -- Fullscreen on special:wine is dropped when the window is moved
    -- back. Wait until it is on a real workspace.
    if workspace_name(w):find("special:wine", 1, true) then
        if not armed[addr .. ":park"] and hl.timer then
            armed[addr .. ":park"] = true
            hl.timer(function()
                armed[addr .. ":park"] = nil
                pcall(consider, w)
            end, { timeout = 300, type = "oneshot" })
        end
        return
    end
    local fs = fs_of(w)
    -- Already covering the screen. A later drop to maximized is the
    -- game restating windowed fullscreen; a drop to 0 is SUPER+F.
    if fs >= 2 then
        covered[addr] = true
        yielded[addr] = nil
        return
    end
    if covered[addr] and fs == 0 then
        done[addr] = true
        return
    end
    if (tries[addr] or 0) >= 4 then
        done[addr] = true
        return
    end
    if other_game_holds(w) then
        yielded[addr] = true
        return
    end
    if armed[addr] then
        return
    end
    tries[addr] = (tries[addr] or 0) + 1
    armed[addr] = true
    dispatch_fs(w)
    if not hl.timer then
        return
    end
    hl.timer(function()
        armed[addr] = nil
        if done[addr] then
            return
        end
        local hold = false
        pcall(function()
            if workspace_name(w):find("special:wine", 1, true)
                or other_game_holds(w) then
                hold = true
                return
            end
            if excluded(w) or not is_game(w) or not auto_fs_on() then
                done[addr] = true
                hold = true
            end
        end)
        if not hold then
            pcall(consider, w)
        end
    end, { timeout = 500, type = "oneshot" })
end

-- window.open fires inside Hyprland's mapWindow, before its own
-- fullscreen handover for a window opening over a fullscreen one. A
-- fullscreen dispatch from there crashes 0.57 in setFullscreenMode, so
-- every event only schedules the check for after the map.
-- Do not unset fullscreen from window.fullscreen: SUPER+F is that event,
-- and pulling the launcher back out of it makes the shortcut one-way.
function workspace_name(w)
    local ws = w and w.workspace
    if type(ws) ~= "table" and type(ws) ~= "userdata" then
        return ""
    end
    local ok, name = pcall(function()
        return ws.name
    end)
    if ok and type(name) == "string" then
        return name
    end
    return ""
end

-- The host is parked at map time. If that same window later turns out
-- to be a game (title arrives after map), bring it back and let
-- consider() fullscreen it. The empty desktop never gets a title.
local function release_wine_host(w)
    if not workspace_name(w):find("special:wine", 1, true) then
        return
    end
    if excluded(w) or not is_game(w) then
        return
    end
    local mon = hl.get_active_monitor and hl.get_active_monitor()
    local aw = mon and (mon.activeWorkspace or mon.active_workspace)
    local id = 0
    if type(aw) == "table" then
        id = tonumber(aw.id) or 0
    elseif type(aw) == "number" then
        id = aw
    end
    if id < 1 or not (hl.dispatch and hl.dsp and hl.dsp.window and hl.dsp.window.move) then
        return
    end
    local spec = { workspace = tostring(id), follow = true, window = w }
    local moved = false
    local ok = pcall(function()
        hl.dispatch(hl.dsp.window.move(spec))
        moved = true
    end)
    return ok and moved
end

local function later(w)
    if not hl.timer then
        return
    end
    hl.timer(function()
        local moved = false
        local ok, res = pcall(release_wine_host, w)
        moved = ok and res == true
        -- The move is async. Fullscreening before it lands is discarded.
        if moved then
            hl.timer(function()
                pcall(consider, w)
            end, { timeout = 50, type = "oneshot" })
            return
        end
        pcall(consider, w)
    end, { timeout = 50, type = "oneshot" })
end

-- A game already mapped (reload while it is open) never gets window.open.
if hl.get_windows and hl.timer then
    hl.timer(function()
        local wins = hl.get_windows()
        if type(wins) ~= "table" then
            return
        end
        for i = 1, #wins do
            pcall(later, wins[i])
        end
    end, { timeout = 50, type = "oneshot" })
end

if hl.on then
    hl.on("window.open", later)
    hl.on("window.class", later)
    hl.on("window.title", later)
    hl.on("window.fullscreen", later)
    hl.on("window.close", function(w)
        local a = addr_of(w)
        if a ~= "" then
            done[a] = nil
            armed[a] = nil
            armed[a .. ":park"] = nil
            yielded[a] = nil
            covered[a] = nil
            tries[a] = nil
        end
        -- A login window had the workspace. The game behind it can
        -- take exclusive fullscreen once that window is gone.
        if not hl.timer or not hl.get_windows then
            return
        end
        hl.timer(function()
            local wins = hl.get_windows()
            if type(wins) ~= "table" then
                return
            end
            for i = 1, #wins do
                local o = wins[i]
                if (type(o) == "table" or type(o) == "userdata") and yielded[addr_of(o)] then
                    pcall(consider, o)
                end
            end
        end, { timeout = 50, type = "oneshot" })
    end)
end
