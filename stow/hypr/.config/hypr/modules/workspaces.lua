-- Workspace-to-monitor assignment. config.json's monitors.rules is a list
-- of { workspace = "1-5", monitorDescription = "..." } entries, edited
-- by Settings > Displays. monitors.workspaceMode = fixed reserves 1-5
-- on the leftmost monitor and 6-10 on the next (by x), never by connector
-- name.

local config = require("modules.config")
local json = require("lib.json")

local rules = config.value("monitors.rules", {})

for _, rule in ipairs(rules) do
    if rule.workspace and rule.monitorDescription then
        hl.dsp.workspace.move({ workspace = rule.workspace, monitor = "desc:" .. rule.monitorDescription })
    end
end

local mode = config.value("monitors.workspaceMode", "dynamic")
if mode == "fixed" then
    local monitors = {}
    local handle = io.popen("hyprctl monitors -j 2>/dev/null")
    if handle then
        local raw = handle:read("*a") or "[]"
        handle:close()
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == "table" then
            monitors = decoded
        end
    end
    table.sort(monitors, function(a, b)
        return (a.x or 0) < (b.x or 0)
    end)
    local function bind_range(mon, from, to)
        if not mon or not mon.description then
            return
        end
        local desc = "desc:" .. mon.description
        for id = from, to do
            if hl.workspace_rule then
                hl.workspace_rule({
                    workspace = tostring(id),
                    monitor = desc,
                    persistent = true,
                    default = (id == from),
                })
            end
        end
    end
    bind_range(monitors[1], 1, 5)
    bind_range(monitors[2], 6, 10)
end
