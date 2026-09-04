-- Monitor order and 1–5 / 6–10 / … ranges. Shared by workspaces.lua so
-- pin/adopt never hardcode a connector name.

local config = require("modules.config")

local M = {}

function M.selector(mon)
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

function M.same_output(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    if a.id ~= nil and b.id ~= nil and a.id == b.id then
        return true
    end
    if type(a.description) == "string" and a.description ~= "" and a.description == b.description then
        return true
    end
    if type(a.serial) == "string" and a.serial ~= "" and a.serial == b.serial then
        return true
    end
    return type(a.name) == "string" and a.name ~= "" and a.name == b.name
end

function M.workspace_id(ws)
    if type(ws) == "number" then
        return ws
    end
    if type(ws) == "table" then
        return tonumber(ws.id)
    end
    return tonumber(ws)
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

function M.list_monitors()
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

function M.assignment_monitors()
    local live = M.list_monitors()
    if #live > 0 then
        return live
    end
    return list_from_profiles()
end

function M.range_for_index(i)
    local from = (i - 1) * 5 + 1
    return from, from + 4
end

function M.assigned_monitor(n)
    if type(n) ~= "number" or n < 1 then
        return nil
    end
    return M.assignment_monitors()[math.floor((n - 1) / 5) + 1]
end

function M.live_match(mon)
    if not mon then
        return nil
    end
    for _, m in ipairs(M.list_monitors()) do
        if M.same_output(mon, m) then
            return m
        end
    end
    return mon
end

function M.index_of(mon)
    for i, m in ipairs(M.assignment_monitors()) do
        if M.same_output(m, mon) then
            return i
        end
    end
    return nil
end

function M.active_id(mon)
    local aw = mon and (mon.activeWorkspace or mon.active_workspace)
    if type(aw) == "number" then
        return aw
    end
    if type(aw) == "table" then
        return tonumber(aw.id) or 0
    end
    return tonumber(mon and mon.activeWorkspaceID) or 0
end

function M.fixed()
    return config.value("monitors.workspaceMode", "dynamic") == "fixed"
end

return M
