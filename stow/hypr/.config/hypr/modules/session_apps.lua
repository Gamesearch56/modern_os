-- Session autostart: login/respawn on special:background; park during
-- grace only so interactive Apps.launch stays in the foreground.
local config = require("modules.config")
local paths = require("modules.paths")
-- Prefer shared module; inline fallback so a missing stow link cannot
-- disable the whole login autostart path.
local match
do
    local ok, mod = pcall(require, "modules.session_match")
    if ok and type(mod) == "table" then
        match = mod
    else
        match = {}
        function match.stem(id)
            return tostring(id or ""):gsub("%.desktop$", "")
        end
        function match.norm(s)
            return tostring(s or ""):lower():gsub("%.desktop$", ""):gsub("[%s._%-]+", "")
        end
        function match.url_tokens(needle, fieldn)
            if needle == "" or fieldn == "" then
                return false
            end
            if needle:find("mail", 1, true)
                and (fieldn:find("mailproton", 1, true) or fieldn:find("mailprotonme", 1, true)) then
                return true
            end
            if needle:find("calendar", 1, true)
                and (fieldn:find("calendarproton", 1, true) or fieldn:find("calendarprotonme", 1, true)) then
                return true
            end
            if needle:find("whatsapp", 1, true)
                and (fieldn:find("whatsapp", 1, true) or fieldn:find("webwhatsapp", 1, true)) then
                return true
            end
            return false
        end
        function match.field_matches(raw, desktop_id)
            local needle = match.norm(desktop_id)
            local fieldn = match.norm(raw)
            if needle == "" or fieldn == "" then
                return false
            end
            if match.url_tokens(needle, fieldn) then
                return true
            end
            if fieldn == needle then
                return true
            end
            if #needle >= 5 and fieldn:find(needle, 1, true) then
                return true
            end
            if #fieldn >= 5 and needle:find(fieldn, 1, true) then
                return true
            end
            return false
        end
        function match.window_matches(w, desktop_id)
            if type(w) ~= "table" then
                return false
            end
            for _, raw in ipairs({ w.class, w.initial_class, w.title, w.initial_title }) do
                if match.field_matches(raw, desktop_id) then
                    return true
                end
            end
            return false
        end
    end
end

local M = {}
local park = false
local park_gen = 0
local shutting_down = false
local bg_rules = { workspace = "special:background silent" }

local function park_script()
    return paths.scripts .. "/session-park.sh"
end

local function run_park_script()
    if hl.exec_cmd then
        pcall(hl.exec_cmd, park_script())
    end
end

local function addrs()
    local t = _G.__modern_as_addrs
    if type(t) ~= "table" then
        t = {}
        _G.__modern_as_addrs = t
    end
    return t
end

local function autostart_ids()
    if config.invalidate then
        config.invalidate()
    end
    local list = config.value("general.autostart", {})
    if type(list) ~= "table" then
        return {}
    end
    return list
end

local function in_autostart(name)
    local want = match.norm(name)
    if want == "" then
        return false
    end
    for _, id in ipairs(autostart_ids()) do
        if match.norm(id) == want then
            return true
        end
    end
    return false
end

local function desktop_for_window(w)
    local addr = tostring(w and w.address or "")
    if addr ~= "" then
        local known = addrs()[addr]
        if type(known) == "string" and known ~= "" and in_autostart(known) then
            return known
        end
    end
    for _, id in ipairs(autostart_ids()) do
        if match.window_matches(w, id) then
            return match.stem(id)
        end
    end
    return ""
end

local function remember(w, name)
    local addr = tostring(w and w.address or "")
    if addr ~= "" and name ~= "" then
        addrs()[addr] = name
    end
end

local function forget(w)
    local addr = tostring(w and w.address or "")
    if addr ~= "" then
        addrs()[addr] = nil
    end
end

local function move_bg(w)
    if not (hl.dispatch and hl.dsp and hl.dsp.window and hl.dsp.window.move) then
        return
    end
    local addr = tostring(w and w.address or ""):gsub("^address:", "")
    -- Wiki: window.move({ workspace, follow?, window? }) — no "silent" key;
    -- follow=false keeps the current workspace focused (scratchpad park).
    local function try(spec)
        return pcall(function()
            hl.dispatch(hl.dsp.window.move(spec))
        end)
    end
    if addr ~= "" and try({
        workspace = "special:background",
        follow = false,
        window = "address:" .. addr,
    }) then
        return
    end
    try({
        workspace = "special:background",
        follow = false,
        window = w,
    })
end

local function arm_park(ms)
    park = true
    park_gen = park_gen + 1
    local gen = park_gen
    if hl.timer then
        hl.timer(function()
            if gen == park_gen then
                park = false
            end
        end, { timeout = ms or 90000, type = "oneshot" })
    end
end

-- Direct --app= keeps the PID closer to the window than gtk-launch (wiki:
-- exec_cmd rules track the spawned PID; forks drop the rule).
local direct_app = {
    ["proton-mail"] = "vivaldi-stable --app=https://mail.proton.me",
    ["proton-calendar"] = "vivaldi-stable --app=https://calendar.proton.me",
    ["whatsapp"] = "vivaldi-stable --app=https://web.whatsapp.com",
}

local function launch_name(name)
    local cmd = direct_app[name] or (paths.modern_launch .. " " .. name)
    if hl.dispatch and hl.dsp and hl.dsp.exec_cmd then
        pcall(function()
            hl.dispatch(hl.dsp.exec_cmd(cmd, bg_rules))
        end)
    else
        hl.exec_cmd(cmd, bg_rules)
    end
    if hl.timer then
        hl.timer(run_park_script, { timeout = 1500, type = "oneshot" })
    end
end

local function park_app_window(w)
    local name = desktop_for_window(w)
    if name == "" then
        return
    end
    remember(w, name)
    if not park then
        return
    end
    move_bg(w)
end

local function sweep_parked()
    local wins = hl.get_windows and hl.get_windows()
    if type(wins) ~= "table" then
        return
    end
    for _, w in pairs(wins) do
        if type(w) == "table" and desktop_for_window(w) ~= "" then
            local ws = w.workspace
            local wsname = ""
            if type(ws) == "table" then
                wsname = tostring(ws.name or "")
            end
            if not (wsname:find("special:background", 1, true) or wsname == "background") then
                move_bg(w)
            end
        end
    end
end

local function schedule_sweeps()
    if not hl.timer then
        return
    end
    for _, ms in ipairs({ 1000, 2500, 5000, 8000, 12000, 20000, 35000, 60000 }) do
        hl.timer(function()
            if not park then
                return
            end
            sweep_parked()
            run_park_script()
        end, { timeout = ms, type = "oneshot" })
    end
end

local function start_apps()
    local list = autostart_ids()
    arm_park(90000)
    schedule_sweeps()
    run_park_script()
    local delay = 0
    for _, id in ipairs(list) do
        local name = match.stem(id)
        if name ~= "" then
            local wait = delay
            if wait <= 0 then
                launch_name(name)
            elseif hl.timer then
                hl.timer(function()
                    launch_name(name)
                end, { timeout = wait, type = "oneshot" })
            else
                launch_name(name)
            end
            delay = delay + 2500
        end
    end
end

function M.on_start()
    if hl.timer then
        hl.timer(start_apps, { timeout = 2000, type = "oneshot" })
    else
        start_apps()
    end
end

if hl.on then
    hl.on("window.open", park_app_window)
    hl.on("window.class", park_app_window)
    hl.on("window.title", park_app_window)
    hl.on("hyprland.shutdown", function()
        shutting_down = true
    end)
    hl.on("window.close", function(w)
        if shutting_down then
            return
        end
        local name = desktop_for_window(w)
        forget(w)
        if name == "" or not in_autostart(name) then
            return
        end
        local busy = _G.__modern_as_busy
        if type(busy) ~= "table" then
            busy = {}
            _G.__modern_as_busy = busy
        end
        if busy[name] then
            return
        end
        busy[name] = true
        arm_park(20000)
        launch_name(name)
        if hl.timer then
            hl.timer(run_park_script, { timeout = 2500, type = "oneshot" })
            hl.timer(function()
                if type(_G.__modern_as_busy) == "table" then
                    _G.__modern_as_busy[name] = nil
                end
            end, { timeout = 8000, type = "oneshot" })
        end
    end)
end

return M
