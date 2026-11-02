-- Session autostart: spawn on login/respawn onto special:background.
-- Mail, calendar, and WhatsApp are one Vivaldi process (--app windows).
-- A process-wide workspace rule would also hide the browser, so each
-- mapped app window is moved after it has a class. Super+Q / taskbar
-- still own interactive park.
local config = require("modules.config")
local paths = require("modules.paths")
local workspaces = require("modules.workspaces")
local direct_app = require("modules.session_direct_apps")

local ok_match, match = pcall(require, "modules.session_match")
if not ok_match or type(match) ~= "table" then
    error("modules.session_match required (restow hypr)")
end

local M = {}
local shutting_down = false

local function pin_background()
    if workspaces.pin_background then
        workspaces.pin_background()
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
    return type(list) == "table" and list or {}
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

-- A mail notice uses the same app id as the inbox. Closing the notice
-- must not start a second Proton Mail while the inbox is still mapped.
local function another_open(name, closed_addr)
    if not hl.get_windows then
        return false
    end
    local wins = hl.get_windows()
    if type(wins) ~= "table" then
        return false
    end
    for i = 1, #wins do
        local w = wins[i]
        if (type(w) == "table" or type(w) == "userdata") and tostring(w.address or "") ~= closed_addr then
            if match.window_matches(w, name) then
                return true
            end
        end
    end
    return false
end

local function workspace_name(w)
    local ws = w and w.workspace
    if type(ws) == "table" or type(ws) == "userdata" then
        local ok, name = pcall(function()
            return ws.name
        end)
        if ok and name ~= nil then
            return tostring(name)
        end
    end
    return tostring(ws or "")
end

local function on_special(w)
    local n = workspace_name(w)
    return n:find("special:background", 1, true) ~= nil or n == "background"
end

local function move_to_background(w)
    if not (hl.dispatch and hl.dsp and hl.dsp.window and hl.dsp.window.move) then
        return
    end
    -- Create the special workspace if this is the first park, then
    -- close it so the moved window is not left on screen.
    pin_background()
    -- A window object is what the compositor accepts. An address string
    -- without the 0x prefix is a silent no-op.
    -- Dispatch does not error when the move is ignored, so try the
    -- window and the address. One of the two sticks once the window
    -- has a workspace.
    local spec = { workspace = "special:background", follow = false, window = w }
    pcall(hl.dispatch, hl.dsp.window.move(spec))
    local addr = tostring(w and w.address or ""):gsub("^address:", "")
    if addr ~= "" and not addr:lower():find("^0x") then
        addr = "0x" .. addr
    end
    if addr == "" then
        return
    end
    spec.window = "address:" .. addr
    pcall(hl.dispatch, hl.dsp.window.move(spec))
end

local function on_window(w)
    local name = desktop_for_window(w)
    if name == "" then
        return
    end
    remember(w, name)
    local spawn = _G.__modern_as_spawn
    if type(spawn) ~= "table" or not spawn[name] then
        return
    end
    if on_special(w) then
        spawn[name] = nil
        return
    end
    move_to_background(w)
end

local function mark_spawn(name)
    local t = _G.__modern_as_spawn
    if type(t) ~= "table" then
        t = {}
        _G.__modern_as_spawn = t
    end
    t[name] = true
    if hl.timer then
        hl.timer(function()
            if type(_G.__modern_as_spawn) == "table" then
                _G.__modern_as_spawn[name] = nil
            end
        end, { timeout = 20000, type = "oneshot" })
    end
end

local function launch_name(name)
    local cmd = direct_app[name] or (paths.modern_launch .. " " .. name)
    pin_background()
    mark_spawn(name)
    -- Do not pin every window of this process. The decryption warning has
    -- no app class; a process rule parked it on the hidden workspace, so
    -- the browser looked like it never opened. on_window parks the app.
    if hl.dispatch and hl.dsp and hl.dsp.exec_cmd then
        pcall(function()
            hl.dispatch(hl.dsp.exec_cmd(cmd))
        end)
    else
        hl.exec_cmd(cmd)
    end
end

-- The app class often arrives after the first map event. While the
-- spawn mark is set, look again so a late class still leaves workspace 1.
local function each_window(fn)
    if not hl.get_windows then
        return
    end
    local wins = hl.get_windows()
    if type(wins) ~= "table" then
        return
    end
    local list = wins
    if #wins == 0 then
        list = {}
        for _, w in pairs(wins) do
            list[#list + 1] = w
        end
    end
    for i = 1, #list do
        if type(list[i]) == "table" or type(list[i]) == "userdata" then
            fn(list[i])
        end
    end
end

local function retry_background()
    each_window(on_window)
end

local function arm_background_retries()
    if not hl.timer then
        retry_background()
        return
    end
    for _, wait in ipairs({ 600, 1800, 4500 }) do
        hl.timer(retry_background, { timeout = wait, type = "oneshot" })
    end
end

local function start_apps()
    pin_background()
    local list = autostart_ids()
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
            delay = delay + 200
        end
    end
    arm_background_retries()
end

-- Vivaldi checks for a notification service once, at launch. If mail
-- starts first, every later message is its own tiled window.
local function notifier_ready()
    local ok_f, f = pcall(io.popen, "busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; printf %s $?", "r")
    if not ok_f or not f then
        return false
    end
    local s = f:read("*a") or ""
    f:close()
    return s:match("^0$") ~= nil
end

local bus_tries = 0

local function start_when_ready()
    bus_tries = bus_tries + 1
    if notifier_ready() or bus_tries >= 40 then
        start_apps()
        return
    end
    if hl.timer then
        hl.timer(start_when_ready, { timeout = 250, type = "oneshot" })
    else
        start_apps()
    end
end

function M.on_start()
    pin_background()
    if hl.timer then
        hl.timer(start_when_ready, { timeout = 250, type = "oneshot" })
    else
        start_apps()
    end
end

if hl.on and not _G.__modern_session_hooked then
    _G.__modern_session_hooked = true
    hl.on("window.open_early", on_window)
    hl.on("window.open", on_window)
    hl.on("window.class", on_window)
    hl.on("window.title", on_window)
    hl.on("hyprland.shutdown", function()
        shutting_down = true
    end)
    hl.on("window.close", function(w)
        if shutting_down then
            return
        end
        local closed = tostring(w and w.address or "")
        local name = desktop_for_window(w)
        forget(w)
        if name == "" or not in_autostart(name) or another_open(name, closed) then
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

-- A reload drops the address map. Remember windows that are already
-- open so closing one still relaunches that app.
local function seed_open()
    if not hl.get_windows then
        return
    end
    local wins = hl.get_windows()
    if type(wins) ~= "table" then
        return
    end
    for i = 1, #wins do
        local w = wins[i]
        if type(w) == "table" or type(w) == "userdata" then
            local name = desktop_for_window(w)
            if name ~= "" then
                remember(w, name)
            end
        end
    end
end

if hl.timer then
    hl.timer(seed_open, { timeout = 300, type = "oneshot" })
else
    seed_open()
end

-- Cold boot maps the apps before any spawn mark exists, and the first
-- move is overwritten by that placement. Keep correcting until login
-- has finished. Later raises are left alone.
local function park_open_apps()
    each_window(function(w)
        if desktop_for_window(w) ~= "" and not on_special(w) then
            move_to_background(w)
        end
    end)
end

if not _G.__modern_bg_startup_park then
    _G.__modern_bg_startup_park = true
    if hl.timer then
        for _, wait in ipairs({ 500, 2000, 5000, 10000, 15000 }) do
            hl.timer(park_open_apps, { timeout = wait, type = "oneshot" })
        end
    else
        park_open_apps()
    end
end

return M
