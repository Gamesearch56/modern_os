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
    local home = layout.assigned_monitor(n)
    local on = win.monitor
    if not n or not home or not on then
        return
    end
    if layout.same_output(on, layout.live_match(home) or home) then
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
end

function M.focus(n)
    if config.invalidate then
        config.invalidate()
    end
    apply_fixed()
    if layout.fixed() then
        pin(n)
        hl.dispatch(hl.dsp.focus({ workspace = n }))
        return
    end
    hl.dispatch(hl.dsp.focus({ workspace = n, on_current_monitor = true }))
end

function M.move_window(n)
    if config.invalidate then
        config.invalidate()
    end
    apply_fixed()
    if layout.fixed() then
        pin(n)
    end
    if hl.dsp.window and hl.dsp.window.move then
        hl.dispatch(hl.dsp.window.move({ workspace = n }))
        return
    end
    hl.dispatch(hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace " .. tostring(n)))
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
