-- Session autostart apps: spawn on login on special:background, park
-- late-mapping windows there, and respawn if the client quits so
-- mail/chat keep notifying. Raise is Hypr.raiseDesktop / modern-launch.
local config = require("modules.config")
local paths = require("modules.paths")

local M = {}
local park = false
local shutting_down = false
-- Hyprland windowrule-style workspace token for exec_cmd.
local bg_rules = { workspace = "special:background silent" }

local function stem(id)
    return tostring(id or ""):gsub("%.desktop$", "")
end

local function norm(s)
    return tostring(s or ""):lower():gsub("%.desktop$", ""):gsub("[%s._%-]+", "")
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

-- Vivaldi --app= windows use URL-derived classes, not StartupWMClass.
local function vivaldi_app_match(classn, needle)
    if not classn:find("^vivaldi") then
        return false
    end
    if classn:find(needle, 1, true) then
        return true
    end
    -- proton-mail.desktop → …mail.proton.me…
    if needle:find("mail", 1, true) and classn:find("mailproton", 1, true) then
        return true
    end
    if needle:find("calendar", 1, true) and classn:find("calendarproton", 1, true) then
        return true
    end
    if needle:find("whatsapp", 1, true) and classn:find("whatsapp", 1, true) then
        return true
    end
    return false
end

local function window_matches(w, desktop_id)
    local needle = norm(desktop_id)
    if needle == "" or type(w) ~= "table" then
        return false
    end
    local fields = {
        w.class,
        w.initial_class,
        w.title,
        w.initial_title,
    }
    for _, raw in ipairs(fields) do
        local class = tostring(raw or "")
        local classn = norm(class)
        if classn ~= "" then
            if vivaldi_app_match(classn, needle) then
                return true
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
        end
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

local function arm_park(ms)
    park = true
    if hl.timer then
        hl.timer(function()
            park = false
        end, { timeout = ms or 60000, type = "oneshot" })
    end
end

local function launch_name(name)
    -- Every general.autostart entry opens on special:background.
    local cmd = paths.modern_launch .. " " .. name
    hl.exec_cmd(cmd, bg_rules)
end

local function park_app_window(w)
    if desktop_for_window(w) == "" then
        return
    end
    -- Always re-park during the login grace window. After that, only
    -- park if the client somehow mapped on a normal workspace while
    -- we still expect a quiet spawn (park flag).
    if not park then
        return
    end
    move_bg(w)
end

local function start_apps()
    local list = autostart_ids()
    arm_park(60000)
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
    -- Vivaldi --app= often maps as vivaldi-stable then renames.
    hl.on("window.class", park_app_window)
    hl.on("window.title", park_app_window)
    hl.on("hyprland.shutdown", function()
        shutting_down = true
    end)
    -- Client close (window X) cannot be cancelled. Respawn on
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
        arm_park(20000)
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
