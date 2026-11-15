-- Workspace-to-monitor assignment. `fixed` keeps five workspaces per
-- display from left to right (1-5, 6-10, 11-15, …), keyed on
-- description never connector name. Live outputs win over profiles so
-- a third panel is not stuck on Hyprland's default workspace 11.
-- A window dragged onto another output joins that output's workspace;
-- apply_fixed must not yank the workspace (and the window) back.

local config = require("modules.config")
local layout = require("modules.workspaces_layout")

local M = {}

local adopting = false

local function dest_workspace(mon)
    local i = layout.index_of(mon)
    if not i then
        return nil
    end
    local from, to = layout.range_for_index(i)
    local sel = layout.selector(mon)
    if hl.get_last_workspace then
        local last = hl.get_last_workspace(sel or mon)
        local id = layout.workspace_id(last)
        if id and id >= from and id <= to then
            return id
        end
    end
    local cur = layout.active_id(layout.live_match(mon) or mon)
    if cur >= from and cur <= to then
        return cur
    end
    return from
end

local function send_to_workspace(win, n)
    if adopting or not win or not n or not hl.dsp.window or not hl.dsp.window.move then
        return
    end
    adopting = true
    local spec = { workspace = n, follow = false, window = win }
    local ok = pcall(hl.dispatch, hl.dsp.window.move(spec))
    if not ok and win.address then
        spec.window = "address:" .. tostring(win.address):gsub("^address:", "")
        pcall(hl.dispatch, hl.dsp.window.move(spec))
    end
    adopting = false
end

local function pin(n, mon)
    local dest = mon or layout.assigned_monitor(n)
    local sel = layout.selector(dest)
    if not sel or not hl.dsp.workspace or not hl.dsp.workspace.move then
        return
    end
    local home = layout.live_match(dest) or dest
    local ws = hl.get_workspace and hl.get_workspace(n)
    local cur = ws and ws.monitor
    if cur and layout.same_output(cur, home) then
        return
    end
    -- Drag still showing this workspace on the other output: adopt first.
    local win = hl.get_active_window and hl.get_active_window()
    if win and layout.workspace_id(win.workspace) == n and win.monitor
        and home and not layout.same_output(win.monitor, home) then
        return
    end
    pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = tostring(n), monitor = sel }))
end

local function adopt_if_stray(win)
    if adopting or not layout.fixed() or not win then
        return
    end
    local n = layout.workspace_id(win.workspace)
    -- Special workspaces and intentional raises onto the focused monitor's
    -- workspace must not be yanked into the previous output's 6–10 range.
    if not n or n < 0 then
        return
    end
    local home = layout.assigned_monitor(n)
    local on = win.monitor
    if not home or not on then
        return
    end
    local home_live = layout.live_match(home) or home
    if layout.same_output(on, home_live) then
        return
    end
    local focus_mon = hl.get_active_monitor and hl.get_active_monitor()
    if focus_mon and layout.same_output(focus_mon, home_live) then
        return
    end
    local target = dest_workspace(on)
    if target and target ~= n then
        send_to_workspace(win, target)
    end
end

local function on_workspace_moved(ws, mon)
    if adopting or not layout.fixed() then
        return
    end
    local n = layout.workspace_id(ws)
    local home = layout.assigned_monitor(n)
    if not n or not home or not mon or layout.same_output(mon, layout.live_match(home) or home) then
        return
    end
    local win = hl.get_active_window and hl.get_active_window()
    local target = dest_workspace(mon)
    if win and target and target ~= n then
        send_to_workspace(win, target)
    end
    pin(n, home)
end

local function show(mon, id)
    pin(id, mon)
    if hl.dsp and hl.dsp.focus then
        pcall(hl.dispatch, hl.dsp.focus({ workspace = id }))
    end
end

local function focus_primary()
    local mon = layout.primary()
    if not mon then
        return
    end
    local live = layout.live_match(mon) or mon
    local from = 1
    if layout.fixed() then
        local i = layout.index_of(live) or 1
        from = layout.range_for_index(i)
    else
        local cur = layout.active_id(live)
        from = cur > 0 and cur or 1
    end
    show(live, from)
    local x = (type(live.x) == "number" and live.x or 0)
    local y = (type(live.y) == "number" and live.y or 0)
    local w = (type(live.width) == "number" and live.width or 0)
    local h = (type(live.height) == "number" and live.height or 0)
    if w > 0 and h > 0 and hl.dsp and hl.dsp.cursor and hl.dsp.cursor.move then
        pcall(hl.dispatch, hl.dsp.cursor.move({
            x = math.floor(x + w / 2),
            y = math.floor(y + h / 2),
        }))
    end
end

-- Empty workspace 11 stays until the bound default is focused. Skip
-- when the active id is unknown so layout events do not steal focus.
local function ensure_in_range(mon, from, to)
    local live = layout.live_match(mon)
    if not live then
        return
    end
    local cur = layout.active_id(live)
    if cur <= 0 or (cur >= from and cur <= to) then
        return
    end
    show(live, from)
end

local function has_background()
    if not hl.get_workspaces then
        return false
    end
    local list = hl.get_workspaces()
    if type(list) ~= "table" then
        return false
    end
    local function named(w)
        if type(w) ~= "table" and type(w) ~= "userdata" then
            return false
        end
        local ok, name = pcall(function()
            return w.name
        end)
        return ok and tostring(name or ""):find("special:background", 1, true) ~= nil
    end
    if #list > 0 then
        for i = 1, #list do
            if named(list[i]) then
                return true
            end
        end
        return false
    end
    for _, w in pairs(list) do
        if named(w) then
            return true
        end
    end
    return false
end

local function workspace_label(obj)
    if type(obj) == "string" then
        return obj
    end
    if type(obj) ~= "table" and type(obj) ~= "userdata" then
        return ""
    end
    local ok, name = pcall(function()
        return obj.name
    end)
    if ok and name ~= nil then
        return tostring(name)
    end
    return ""
end

local function monitor_special_name(mon)
    if type(mon) ~= "table" and type(mon) ~= "userdata" then
        return ""
    end
    for _, key in ipairs({ "specialWorkspace", "special_workspace", "activeSpecialWorkspace" }) do
        local ok, sp = pcall(function()
            return mon[key]
        end)
        if ok and sp ~= nil then
            local name = workspace_label(sp)
            if name ~= "" then
                return name
            end
        end
    end
    return ""
end

-- toggle_special is the only call that creates special:background, and
-- it shows that workspace on the focused monitor. A window parked there
-- then covers workspace 1, and SUPER+Q cannot hide it.
function M.pin_background()
    local toggle = hl.dsp and hl.dsp.workspace and hl.dsp.workspace.toggle_special
    if not (hl.dispatch and toggle and hl.get_active_monitor and hl.get_active_monitor()) then
        return
    end
    local function flip()
        pcall(hl.dispatch, toggle("background"))
    end
    local function workspace_id_of(ws)
        local id = layout.workspace_id(ws)
        if id then
            return id
        end
        if type(ws) ~= "userdata" and type(ws) ~= "table" then
            return nil
        end
        local ok, n = pcall(function()
            return ws.id
        end)
        if ok then
            return tonumber(n)
        end
        return nil
    end
    -- Toggle only to create. A later toggle while it is open on the
    -- other monitor moves the workspace and drops its windows onto
    -- workspace 1. Focusing the numbered workspace underneath it
    -- closes the view and leaves the windows parked.
    if not has_background() then
        flip()
        flip()
    end
    local prev_id = nil
    local focused_mon = hl.get_active_monitor and hl.get_active_monitor()
    if focused_mon then
        local ok, aw = pcall(function()
            return focused_mon.activeWorkspace
        end)
        prev_id = ok and workspace_id_of(aw) or nil
    end
    local raw = hl.get_monitors and hl.get_monitors()
    if type(raw) == "table" and hl.dsp.focus then
        for _, mon in pairs(raw) do
            if monitor_special_name(mon):find("special:background", 1, true) then
                local ok, aw = pcall(function()
                    return mon.activeWorkspace
                end)
                local id = ok and workspace_id_of(aw) or nil
                if id and id > 0 then
                    pcall(hl.dispatch, hl.dsp.focus({ workspace = id }))
                end
            end
        end
        if prev_id and prev_id > 0 then
            pcall(hl.dispatch, hl.dsp.focus({ workspace = prev_id }))
        end
    end
    if has_background() or not hl.get_workspaces then
        _G.__modern_bg_workspace = true
    end
end

local function bind_range(mon, from, to)
    local sel = layout.selector(mon)
    if not sel or not hl.workspace_rule then
        return
    end
    for id = from, to do
        hl.workspace_rule({
            workspace = tostring(id),
            monitor = sel,
            persistent = true,
            default = (id == from),
        })
        pin(id, mon)
    end
    ensure_in_range(mon, from, to)
end

local function apply_fixed(boot)
    if not layout.fixed() then
        return
    end
    local monitors = layout.assignment_monitors()
    for i, mon in ipairs(monitors) do
        local from, to = layout.range_for_index(i)
        bind_range(mon, from, to)
    end
    if not boot then
        return
    end
    for i = #monitors, 1, -1 do
        local from = layout.range_for_index(i)
        show(layout.live_match(monitors[i]) or monitors[i], from)
    end
    focus_primary()
    M.pin_background()
end

function M.focus(n)
    apply_fixed()
    if layout.fixed() then
        pin(n)
        hl.dispatch(hl.dsp.focus({ workspace = n }))
        return
    end
    hl.dispatch(hl.dsp.focus({ workspace = n, on_current_monitor = true }))
end

function M.move_window(n)
    apply_fixed()
    if layout.fixed() then
        pin(n)
    end
    if hl.dsp.window and hl.dsp.window.move then
        hl.dispatch(hl.dsp.window.move({ workspace = n }))
    end
end

local rules = config.value("monitors.rules", {})
for _, rule in ipairs(rules) do
    if rule.workspace and rule.monitorDescription then
        local spec = { workspace = tostring(rule.workspace), monitor = "desc:" .. rule.monitorDescription }
        if hl.dispatch and hl.dsp.workspace and hl.dsp.workspace.move then
            pcall(hl.dispatch, hl.dsp.workspace.move(spec))
        end
    end
end

apply_fixed()

if hl.on then
    hl.on("hyprland.start", function()
        apply_fixed(true)
        M.pin_background()
        if not layout.fixed() then
            focus_primary()
        end
    end)
    hl.on("monitor.added", apply_fixed)
    hl.on("monitor.removed", apply_fixed)
    hl.on("workspace.move_to_monitor", on_workspace_moved)
    hl.on("window.move_to_workspace", function(win)
        adopt_if_stray(win or (hl.get_active_window and hl.get_active_window()))
    end)
    hl.on("monitor.layout_changed", function()
        if not layout.fixed() then
            return
        end
        adopt_if_stray(hl.get_active_window and hl.get_active_window())
        apply_fixed()
    end)
end

return M
