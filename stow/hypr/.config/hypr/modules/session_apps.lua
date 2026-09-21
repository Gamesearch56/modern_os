-- Session autostart: spawn on login/respawn with exec workspace rules only.
-- Never move existing windows onto special:background from timers or
-- open/class/title handlers — park is Super+Q / taskbar only (shell).
local config = require("modules.config")
local paths = require("modules.paths")
local layout = require("modules.workspaces_layout")

local ok_match, match = pcall(require, "modules.session_match")
if not ok_match or type(match) ~= "table" then
    error("modules.session_match required (restow hypr)")
end

local M = {}
local shutting_down = false
-- Wiki: exec_cmd rules; "silent" avoids focusing that workspace on map.
local bg_rules = {
    workspace = "special:background silent",
    no_initial_focus = true,
}

-- Autostart clients inherit the special workspace's monitor. Left on a
-- secondary output they look like "workspace 6+" and raise gets adopted
-- back into that range.
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

-- Track identity only — never move windows here except finishing a
-- login/respawn spawn when Chromium ignored exec workspace rules.
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
    spawn[name] = nil
    local ws = w and w.workspace
    local wsname = ""
    if type(ws) == "table" then
        wsname = tostring(ws.name or "")
    elseif type(ws) == "string" then
        wsname = ws
    end
    if wsname:find("special:background", 1, true) or wsname == "background" then
        return
    end
    if not (hl.dsp and hl.dsp.window and hl.dsp.window.move) then
        return
    end
    pcall(hl.dispatch, hl.dsp.window.move({
        workspace = "special:background",
        follow = false,
        window = w,
    }))
end

local direct_app = {
    ["proton-mail"] = "vivaldi-stable --app=https://mail.proton.me",
    ["proton-calendar"] = "vivaldi-stable --app=https://calendar.proton.me",
    ["whatsapp"] = "vivaldi-stable --app=https://web.whatsapp.com",
}

local function mark_spawn(name)
    local t = _G.__modern_as_spawn
    if type(t) ~= "table" then
        t = {}
        _G.__modern_as_spawn = t
    end
    t[name] = true
end

local function launch_name(name)
    local cmd = direct_app[name] or (paths.modern_launch .. " " .. name)
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
            -- Stagger so each --app= window is more likely to inherit exec rules.
            delay = delay + 2500
        end
    end
end

function M.on_start()
    pin_background()
    if hl.timer then
        hl.timer(start_apps, { timeout = 2000, type = "oneshot" })
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
    -- Client chrome X cannot be cancelled. Respawn with silent exec rules
    -- so mail/chat keep notifying (still in general.autostart).
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
