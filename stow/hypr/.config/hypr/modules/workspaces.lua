-- Workspace-to-monitor assignment. monitors.workspaceMode default is
-- dynamic. `fixed` reserves 1-5 on the leftmost display and 6-10 on
-- the next (by x), never by connector name. SUPER+N must jump to that
-- monitor rather than creating the workspace on whichever display has focus.

local config = require("modules.config")

local M = {}

local function selector(mon)
    if not mon then
        return nil
    end
    local desc = mon.description
    if type(desc) == "string" and desc ~= "" then
        return "desc:" .. desc
    end
    if type(mon.name) == "string" and mon.name ~= "" then
        return mon.name
    end
    return nil
end

local function list_monitors()
    local mons = {}
    if not hl.get_monitors then
        return mons
    end
    local raw = hl.get_monitors()
    if type(raw) ~= "table" then
        return mons
    end
    for _, m in pairs(raw) do
        if m ~= nil then
            mons[#mons + 1] = m
        end
    end
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

local function assigned_monitor(n)
    local monitors = list_monitors()
    if n >= 1 and n <= 5 then
        return monitors[1]
    end
    if n >= 6 and n <= 10 then
        return monitors[2]
    end
    return nil
end

local function pin(n)
    local sel = selector(assigned_monitor(n))
    if not sel or not hl.dsp.workspace or not hl.dsp.workspace.move then
        return
    end
    pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = tostring(n), monitor = sel }))
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
        pin(id)
    end
end

local function apply_fixed()
    if config.value("monitors.workspaceMode", "dynamic") ~= "fixed" then
        return
    end
    local monitors = list_monitors()
    bind_range(monitors[1], 1, 5)
    bind_range(monitors[2], 6, 10)
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
    hl.on("monitor.added", apply_fixed)
    hl.on("monitor.removed", apply_fixed)
    hl.on("monitor.layout_changed", apply_fixed)
end

return M
