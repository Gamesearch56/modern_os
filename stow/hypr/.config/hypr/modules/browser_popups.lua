-- Chromium and Vivaldi draw some web notifications as a Wayland
-- toplevel that never sets an app id or a title (hyprwm/Hyprland
-- #14087). The layout then tiles that surface, so a one-line toast
-- fills the workspace. Float it and park it under the bar. A dialog
-- from the same process that grows a title stays a floating dialog.

local TOAST_W, TOAST_H, MARGIN, BAR_FALLBACK, SETTLE_MS = 440, 176, 12, 48, 120
local focused, state = nil, {}
local CLASS_KEYS = { "class", "initial_class", "initialClass" }
local TITLE_KEYS = { "title", "initial_title", "initialTitle" }

local function addr_of(w)
    return type(w) == "table" and tostring(w.address or "") or ""
end

local function field(w, keys)
    for i = 1, #keys do
        local v = w[keys[i]]
        if type(v) == "string" and v ~= "" then
            return v
        end
    end
    return ""
end

local function browser_pid(w)
    local pid = tonumber(w.pid) or 0
    if pid <= 0 then
        return false
    end
    local f = io.open("/proc/" .. tostring(pid) .. "/comm", "r")
    if not f then
        return false
    end
    local comm = (f:read("*l") or ""):gsub("%s+", "")
    f:close()
    if comm == "vivaldi" or comm == "vivaldi-bin" or comm == "chromium" or comm == "electron" then
        return true
    end
    return comm:sub(1, 6) == "chrome" or comm:sub(1, 13) == "google-chrome" or comm:sub(1, 5) == "brave"
end

local function browser_class(class)
    local c = class:lower()
    return c:find("vivaldi", 1, true) or c:find("chrome", 1, true)
        or c:find("chromium", 1, true) or c:find("brave", 1, true) or c:find("electron", 1, true)
end

-- "mail.proton.me • jetzt": origin, bullet, relative time. A real
-- browser window title carries a " - " suffix (" - Vivaldi").
local function origin_stamp(title)
    if title == "" or #title > 96 or title:find(" - ", 1, true) then
        return false
    end
    return title:find(" • ", 1, true) ~= nil or title:find(" · ", 1, true) ~= nil
end

local function kind_of(w)
    local class, title = field(w, CLASS_KEYS), field(w, TITLE_KEYS)
    if origin_stamp(title) and (class == "" or browser_class(class)) then
        return "toast"
    end
    if not browser_pid(w) then
        return nil
    end
    if class == "" and title == "" then
        return "pending"
    end
    if class == "" then
        return "dialog"
    end
    return "app"
end

local function dispatch(spec)
    if hl.dispatch and spec then
        pcall(hl.dispatch, spec)
    end
end

local function win()
    return hl.dsp and hl.dsp.window
end

local function float_set(w, on)
    if win() and win().float then
        dispatch(win().float({ action = on and "set" or "unset", window = w }))
    end
end

local function restore_focus()
    if focused and hl.dsp and hl.dsp.focus then
        dispatch(hl.dsp.focus({ window = focused }))
    end
end

local function place_toast(w)
    local api = win()
    if not api then
        return
    end
    if api.set_prop then
        dispatch(api.set_prop({
            prop = "max_size",
            value = tostring(TOAST_W) .. " " .. tostring(TOAST_H),
            window = w,
        }))
    end
    if api.resize then
        dispatch(api.resize({ x = TOAST_W, y = TOAST_H, window = w }))
    end
    local m = w.monitor
    if type(m) ~= "table" and hl.get_active_monitor then
        m = hl.get_active_monitor()
    end
    if type(m) ~= "table" or not api.move then
        return
    end
    local mw = tonumber(m.width) or 0
    if mw <= 0 then
        return
    end
    local top, right = MARGIN, MARGIN
    if type(m.reserved) == "table" then
        top = top + (tonumber(m.reserved.top) or 0)
        right = right + (tonumber(m.reserved.right) or 0)
    else
        top = top + BAR_FALLBACK
    end
    dispatch(api.move({
        x = (tonumber(m.x) or 0) + mw - TOAST_W - right,
        y = (tonumber(m.y) or 0) + top,
        window = w,
    }))
end

local function apply_kind(w, kind)
    local addr = addr_of(w)
    if addr == "" or kind == nil or state[addr] == kind then
        return
    end
    if kind == "toast" then
        state[addr] = "toast"
        float_set(w, true)
        place_toast(w)
        restore_focus()
    elseif kind == "dialog" and state[addr] ~= "toast" then
        state[addr] = "dialog"
        float_set(w, true)
        if win() and win().center then
            dispatch(win().center({ window = w }))
        end
        if hl.dsp and hl.dsp.focus then
            dispatch(hl.dsp.focus({ window = w }))
        end
    elseif kind == "app" and (state[addr] == "pending" or state[addr] == "dialog") then
        state[addr] = "app"
        float_set(w, false)
    end
end

local function on_open(w)
    local addr = addr_of(w)
    if addr == "" or state[addr] == "toast" or state[addr] == "app" then
        return
    end
    local kind = kind_of(w)
    if kind == nil or kind ~= "pending" then
        apply_kind(w, kind)
        return
    end
    if state[addr] == "pending" then
        return
    end
    state[addr] = "pending"
    float_set(w, true)
    restore_focus()
    if not hl.timer then
        apply_kind(w, "toast")
        return
    end
    hl.timer(function()
        if state[addr] ~= "pending" then
            return
        end
        local again = kind_of(w)
        apply_kind(w, (again == "pending" or again == nil) and "toast" or again)
    end, { timeout = SETTLE_MS, type = "oneshot" })
end

if hl.on then
    hl.on("window.active", function(w)
        if type(w) ~= "table" then
            return
        end
        local st = state[addr_of(w)]
        if st == "pending" or st == "toast" or st == "dialog" then
            return
        end
        local class, title = field(w, CLASS_KEYS), field(w, TITLE_KEYS)
        if origin_stamp(title) or (class == "" and title == "" and browser_pid(w)) then
            return
        end
        focused = w
    end)
    hl.on("window.open_early", on_open)
    hl.on("window.open", on_open)
    hl.on("window.title", on_open)
    hl.on("window.class", on_open)
    hl.on("window.close", function(w)
        state[addr_of(w)] = nil
    end)
end
