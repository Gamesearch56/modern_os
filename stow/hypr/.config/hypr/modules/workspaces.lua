-- Workspace-to-monitor assignment. `fixed` keeps five workspaces per
-- display from left to right (1-5, 6-10, 11-15, …), keyed on
-- description never connector name. Live outputs win over profiles so
-- a third panel is not stuck on Hyprland's default workspace 11.

local config = require("modules.config")

local M = {}

local function selector(mon)
    if not mon then
        return nil
    end
    if type(mon.description) == "string" and mon.description ~= "" then
        return "desc:" .. mon.description
    end
    if type(mon.name) == "string" and mon.name ~= "" then
        return mon.name
    end
    return nil
end

local function sort_by_x(mons)
    table.sort(mons, function(a, b)
        local ax = (type(a.x) == "number" and a.x) or 0
        local bx = (type(b.x) == "number" and b.x) or 0
        if ax == bx then
            return (a.id or 0) < (b.id or 0)
        end
        return ax < bx
    end)
    return mons
end

local function list_monitors()
    local mons = {}
    local raw = hl.get_monitors and hl.get_monitors()
    if type(raw) ~= "table" then
        return mons
    end
    for _, m in pairs(raw) do
        if m ~= nil then
            mons[#mons + 1] = m
        end
    end
    return sort_by_x(mons)
end

local function list_from_profiles()
    local profiles = config.value("monitors.profiles", {})
    local mons = {}
    if type(profiles) ~= "table" then
        return mons
    end
    for desc, p in pairs(profiles) do
        if type(desc) == "string" and desc ~= "" and type(p) == "table" then
            local x = 0
            if type(p.position) == "string" then
                x = tonumber(p.position:match("^(%-?%d+)x")) or 0
            end
            mons[#mons + 1] = { description = desc, x = x, id = #mons }
        end
    end
    return sort_by_x(mons)
end

local function assignment_monitors()
    local live = list_monitors()
    if #live > 0 then
        return live
    end
    return list_from_profiles()
end

local function range_for_index(i)
    local from = (i - 1) * 5 + 1
    return from, from + 4
end

local function assigned_monitor(n)
    if type(n) ~= "number" or n < 1 then
        return nil
    end
    local monitors = assignment_monitors()
    return monitors[math.floor((n - 1) / 5) + 1]
end

local function pin(n, mon)
    local sel = selector(mon or assigned_monitor(n))
    if not sel or not hl.dsp.workspace or not hl.dsp.workspace.move then
        return
    end
    pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = tostring(n), monitor = sel }))
end

local function live_match(mon)
    if not mon then
        return nil
    end
    for _, m in ipairs(list_monitors()) do
        if mon.description and m.description == mon.description then
            return m
        end
        if mon.name and m.name == mon.name then
            return m
        end
    end
    return mon
end

local function active_id(mon)
    local aw = mon and (mon.activeWorkspace or mon.active_workspace)
    if type(aw) == "number" then
        return aw
    end
    if type(aw) == "table" then
        return tonumber(aw.id) or 0
    end
    return tonumber(mon and mon.activeWorkspaceID) or 0
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
    local live = live_match(mon)
    if not live then
        return
    end
    local cur = active_id(live)
    if cur <= 0 or (cur >= from and cur <= to) then
        return
    end
    show(live, from)
end

local function bind_range(mon, from, to)
    local sel = selector(mon)
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
    if config.value("monitors.workspaceMode", "dynamic") ~= "fixed" then
        return
    end
    local monitors = assignment_monitors()
    for i, mon in ipairs(monitors) do
        local from, to = range_for_index(i)
        bind_range(mon, from, to)
    end
    if not boot then
        return
    end
    for i = #monitors, 1, -1 do
        local from = range_for_index(i)
        show(live_match(monitors[i]) or monitors[i], from)
    end
end

function M.focus(n)
    if config.invalidate then
        config.invalidate()
    end
    apply_fixed()
    if config.value("monitors.workspaceMode", "dynamic") == "fixed" then
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
    if config.value("monitors.workspaceMode", "dynamic") == "fixed" then
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
    hl.on("monitor.layout_changed", apply_fixed)
end

return M
