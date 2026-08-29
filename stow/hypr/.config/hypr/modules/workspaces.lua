-- Workspace-to-monitor assignment. monitors.workspaceMode = fixed
-- reserves 1-5 on the leftmost display and 6-10 on the next (by x),
-- never by connector name (DP-1). Persistent rules keep empty chips
-- alive; existing workspaces are moved onto the bound monitor.

local config = require("modules.config")

local rules = config.value("monitors.rules", {})

for _, rule in ipairs(rules) do
    if rule.workspace and rule.monitorDescription then
        local spec = { workspace = tostring(rule.workspace), monitor = "desc:" .. rule.monitorDescription }
        if hl.dispatch and hl.dsp.workspace and hl.dsp.workspace.move then
            pcall(hl.dispatch, hl.dsp.workspace.move(spec))
        end
    end
end

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
        if hl.dispatch and hl.dsp.workspace and hl.dsp.workspace.move then
            pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = tostring(id), monitor = sel }))
        end
    end
end

local function apply_fixed()
    if config.value("monitors.workspaceMode", "fixed") ~= "fixed" then
        return
    end
    local monitors = list_monitors()
    bind_range(monitors[1], 1, 5)
    bind_range(monitors[2], 6, 10)
end

apply_fixed()

if hl.on then
    hl.on("monitor.added", apply_fixed)
    hl.on("monitor.removed", apply_fixed)
    hl.on("monitor.layout_changed", apply_fixed)
end
