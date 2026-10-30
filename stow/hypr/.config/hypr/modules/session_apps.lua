-- Session autostart: spawn on login/respawn onto special:background.
-- Per-app Vivaldi profiles (session_direct_apps) so each process inherits
-- exec_cmd workspace rules. Spawn expect finishes placement when a marked
-- window maps off special — Super+Q / taskbar still own interactive park.
local config = require("modules.config")
local paths = require("modules.paths")
local layout = require("modules.workspaces_layout")
local direct_app = require("modules.session_direct_apps")

local ok_match, match = pcall(require, "modules.session_match")
if not ok_match or type(match) ~= "table" then
    error("modules.session_match required (restow hypr)")
end

local M = {}
local shutting_down = false
local bg_rules = {
    workspace = "special:background silent",
    no_initial_focus = true,
}

local function pin_background()
    local mon = layout.primary()
    local sel = layout.selector(mon)
    if not sel or not hl.dsp or not hl.dsp.workspace or not hl.dsp.workspace.move then
        return
    end
    pcall(hl.dispatch, hl.dsp.workspace.move({
        workspace = "special:background",
        monitor = sel,
    }))
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
    local json_ok, json = pcall(require, "lib.json")
    if not json_ok then
        return false
    end
    local ok_f, f = pcall(io.popen, "hyprctl clients -j 2>/dev/null", "r")
    if not ok_f or not f then
        return false
    end
    local raw = f:read("*a") or ""
    f:close()
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then
        return false
    end
    for i = 1, #data do
        local c = data[i]
        if type(c) == "table" and tostring(c.address or "") ~= closed_addr then
            local w = {
                class = c.class,
                initial_class = c.initialClass,
                title = c.title,
                initial_title = c.initialTitle,
            }
            if match.window_matches(w, name) then
                return true
            end
        end
    end
    return false
end

local function on_special(w)
    local ws = w and w.workspace
    local n = type(ws) == "table" and tostring(ws.name or "") or tostring(ws or "")
    return n:find("special:background", 1, true) ~= nil or n == "background"
end

local function move_to_background(w)
    if not (hl.dsp and hl.dsp.window and hl.dsp.window.move) then
        return
    end
    local addr = tostring(w and w.address or ""):gsub("^address:", "")
    if addr ~= "" and not addr:lower():find("^0x") then
        addr = "0x" .. addr
    end
    local spec = { workspace = "special:background", follow = false }
    if addr ~= "" then
        spec.window = "address:" .. addr
    else
        spec.window = w
    end
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
    if hl.dispatch and hl.dsp and hl.dsp.exec_cmd then
        pcall(function()
            hl.dispatch(hl.dsp.exec_cmd(cmd, bg_rules))
        end)
    else
        hl.exec_cmd(cmd, bg_rules)
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
end

function M.on_start()
    pin_background()
    if hl.timer then
        hl.timer(start_apps, { timeout = 250, type = "oneshot" })
    else
        start_apps()
    end
end

if hl.on then
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

return M
