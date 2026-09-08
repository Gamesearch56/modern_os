-- Session autostart apps: spawn on login, park Vivaldi --app= windows
-- on special:background, and put them back there instead of dying.
local config = require("modules.config")
local paths = require("modules.paths")

local M = {}
local park = false
local shutting_down = false
local bg_rules = { workspace = "special:background silent" }

local function stem(id)
    return tostring(id or ""):gsub("%.desktop$", "")
end

local function norm(s)
    return tostring(s or ""):lower():gsub("%.desktop$", ""):gsub("[%s._%-]+", "")
end

local function is_background(name)
    if name == "" then
        return false
    end
    for _, role in ipairs({ "calendar", "mail", "communication" }) do
        if stem(config.value("apps.defaults." .. role, "")) == name then
            return true
        end
    end
    return false
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

local function window_matches(w, desktop_id)
    local needle = norm(desktop_id)
    if needle == "" or type(w) ~= "table" then
        return false
    end
    local class = tostring(w.class or w.initial_class or "")
    local classn = norm(class)
    if class:find("^vivaldi%-") and class:find("__%-Default", 1, true) then
        if classn:find(needle, 1, true) then
            return true
        end
        if needle:find("mail", 1, true) and classn:find("mailproton", 1, true) then
            return true
        end
        if needle:find("calendar", 1, true) and classn:find("calendarproton", 1, true) then
            return true
        end
        return false
    end
    if classn == needle then
        return true
    end
    if #needle >= 5 and classn:find(needle, 1, true) then
        return true
    end
    if #classn >= 5 and needle:find(classn, 1, true) then
        return true
    end
    return false
end

local function desktop_for_window(w)
    local list = autostart_ids()
    for _, id in ipairs(list) do
        if window_matches(w, id) then
            return stem(id)
        end
    end
    return ""
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

local function arm_park()
    park = true
    if hl.timer then
        hl.timer(function()
            park = false
        end, { timeout = 15000, type = "oneshot" })
    end
end

local function launch_name(name)
    local cmd = paths.modern_launch .. " " .. name
    if is_background(name) then
        hl.exec_cmd(cmd, bg_rules)
    else
        hl.exec_cmd(cmd)
    end
end

local function park_app_window(w)
    if not park or desktop_for_window(w) == "" then
        return
    end
    move_bg(w)
end

local function start_apps()
    local list = autostart_ids()
    arm_park()
    for _, id in ipairs(list) do
        local name = stem(id)
        if name ~= "" then
            launch_name(name)
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
    hl.on("hyprland.shutdown", function()
        shutting_down = true
    end)
    -- Client close (Vivaldi X) cannot be cancelled. Respawn on
    -- special:background so mail/chat keep notifying.
    hl.on("window.close", function(w)
        if shutting_down then
            return
        end
        local name = desktop_for_window(w)
        if name == "" then
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
        arm_park()
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
