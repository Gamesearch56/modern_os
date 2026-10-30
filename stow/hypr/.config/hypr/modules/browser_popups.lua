-- Chromium and Vivaldi draw some web notifications as a Wayland
-- toplevel that never sets an app id or a title (hyprwm/Hyprland
-- #14087). The layout then tiles that surface, so a one-line toast
-- fills the workspace. Float it and park it under the bar. A dialog
-- from the same process that grows a title stays a floating dialog.

local TOAST_W, TOAST_H, MARGIN, BAR_FALLBACK, SETTLE_MS = 440, 176, 12, 48, 120
local focused, state, seen = nil, {}, {}
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
    -- vivaldi-bin is the --app process (mail, calendar). vivaldi-stable
    -- is the same binary when the desktop entry launches it.
    if comm:sub(1, 7) == "vivaldi" or comm == "chromium" or comm == "electron" then
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

-- vivaldi-mail.proton.me__-Default is the --app window. vivaldi-stable
-- (no dot) is the normal browser and must keep tiling.
local function app_class(class)
    return class:find("^vivaldi%-") ~= nil and class:find(".", 1, true) ~= nil
end

local function host_of(class)
    return class:match("^vivaldi%-(.+)__%-") or ""
end

-- The inbox title is the site or "Postfach | … | Proton Mail". A notice
-- is either untitled or a short subject. The bullet form is origin_stamp.
local function document_title(class, title)
    if title == "" or origin_stamp(title) then
        return false
    end
    if title:find(" | ", 1, true) or title:find("_/", 1, true) then
        return true
    end
    if title:find("Proton Mail", 1, true) or title:find("Proton Calendar", 1, true) then
        return true
    end
    local host = host_of(class)
    return host ~= "" and (title == host or title:sub(1, #host + 1) == host .. "/")
end

local function note(w)
    local class, addr = field(w, CLASS_KEYS), addr_of(w)
    if not app_class(class) or addr == "" then
        return
    end
    local bucket = seen[class]
    if not bucket then
        bucket = {}
        seen[class] = bucket
    end
    bucket[addr] = true
end

local function sibling(class, addr)
    local bucket = seen[class]
    if not bucket then
        return false
    end
    for a in pairs(bucket) do
        if a ~= addr then
            return true
        end
    end
    return false
end

local function kind_of(w)
    local class, title = field(w, CLASS_KEYS), field(w, TITLE_KEYS)
    if origin_stamp(title) and (class == "" or browser_class(class)) then
        return "toast"
    end
    -- The mail app is already open on the background workspace. A further
    -- window from that same app id is Vivaldi's own notice, and it tiles
    -- on the workspace in front of you. The inbox title stays a real window.
    if app_class(class) and sibling(class, addr_of(w)) and not document_title(class, title) then
        return title == "" and "pending" or "toast"
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

local function toast_slot()
    local n = 0
    for _, st in pairs(state) do
        if st == "toast" then
            n = n + 1
        end
    end
    return n
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
        y = (tonumber(m.y) or 0) + top + toast_slot() * (TOAST_H + MARGIN),
        window = w,
    }))
end

local function apply_kind(w, kind)
    local addr = addr_of(w)
    if addr == "" or kind == nil or state[addr] == kind then
        return
    end
    if kind == "toast" then
        float_set(w, true)
        place_toast(w)
        state[addr] = "toast"
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
    note(w)
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
        if app_class(class) and not document_title(class, title) then
            return
        end
        focused = w
    end)
    hl.on("window.open_early", on_open)
    hl.on("window.open", on_open)
    hl.on("window.title", on_open)
    hl.on("window.class", on_open)
    hl.on("window.close", function(w)
        local addr = addr_of(w)
        state[addr] = nil
        local class = field(w, CLASS_KEYS)
        local bucket = seen[class]
        if bucket then
            bucket[addr] = nil
        end
    end)
end

-- Mail is already mapped when this config loads. Asking hyprctl during
-- the reload deadlocks the IPC, so the list is read on the next tick.
local function seed_open_apps()
    local json_ok, json = pcall(require, "lib.json")
    if not json_ok then
        return
    end
    local ok_f, f = pcall(io.popen, "hyprctl clients -j 2>/dev/null", "r")
    if not ok_f or not f then
        return
    end
    local raw = f:read("*a") or ""
    f:close()
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then
        return
    end
    for i = 1, #data do
        local c = data[i]
        if type(c) == "table" then
            note({ class = c.class, initial_class = c.initialClass, address = c.address })
        end
    end
end

if hl.timer then
    hl.timer(seed_open_apps, { timeout = 300, type = "oneshot" })
end
