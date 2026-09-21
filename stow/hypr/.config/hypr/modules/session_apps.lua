-- Session autostart: login/respawn on special:background; park during
-- grace only so interactive Apps.launch stays in the foreground.
local config = require("modules.config")
local paths = require("modules.paths")
local match = require("modules.session_match")
local layout = require("modules.workspaces_layout")

local M = {}
local park = false
local park_gen = 0
local shutting_down = false
local bg_rules = { workspace = "special:background silent" }

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
    pcall(function()
        hl.dispatch(hl.dsp.window.move({
            workspace = "special:background",
            silent = true,
            window = w,
        }))
    end)
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
        end, { timeout = ms or 60000, type = "oneshot" })
    end
end

local function pin_special_to_primary()
    local mon = layout.primary()
    local sel = layout.selector(mon)
    if not sel or not (hl.dispatch and hl.dsp and hl.dsp.workspace and hl.dsp.workspace.move) then
        return
    end
    pcall(function()
        hl.dispatch(hl.dsp.workspace.move({
            workspace = "special:background",
            monitor = sel,
        }))
    end)
end

local function launch_name(name)
    local cmd = paths.modern_launch .. " " .. name
    hl.exec_cmd(cmd, bg_rules)
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
    if not park or not hl.get_windows then
        return
    end
    local wins = hl.get_windows()
    if type(wins) ~= "table" then
        return
    end
    for _, w in pairs(wins) do
        if type(w) == "table" and desktop_for_window(w) ~= "" then
            local ws = w.workspace
            local name = ""
            if type(ws) == "table" then
                name = tostring(ws.name or "")
            end
            if name:find("special:background", 1, true) or name == "background" then
                -- already parked
            else
                move_bg(w)
            end
        end
    end
end

local function schedule_sweeps()
    if not hl.timer then
        return
    end
    for _, ms in ipairs({ 5000, 15000, 45000 }) do
        hl.timer(sweep_parked, { timeout = ms, type = "oneshot" })
    end
end

local function start_apps()
    local list = autostart_ids()
    pin_special_to_primary()
    arm_park(60000)
    schedule_sweeps()
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
            delay = delay + 2000
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
        pin_special_to_primary()
        launch_name(name)
        if hl.timer then
            hl.timer(function()
                if type(_G.__modern_as_busy) == "table" then
                    _G.__modern_as_busy[name] = nil
                end
            end, { timeout = 8000, type = "oneshot" })
        end
    end)
end

return M
