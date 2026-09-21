-- Session autostart: spawn on login/respawn with exec workspace rules only.
-- Never move existing windows onto special:background from timers or
-- open/class/title handlers — park is Super+Q / taskbar only (shell).
local config = require("modules.config")
local paths = require("modules.paths")

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

-- Track identity only — never move windows here.
local function track_window(w)
    local name = desktop_for_window(w)
    if name ~= "" then
        remember(w, name)
    end
end

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
end

local function start_apps()
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
    if hl.timer then
        hl.timer(start_apps, { timeout = 2000, type = "oneshot" })
    else
        start_apps()
    end
end

if hl.on then
    hl.on("window.open", track_window)
    hl.on("window.class", track_window)
    hl.on("window.title", track_window)
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
