-- Workspace-to-monitor assignment. config.json's monitors.rules is a list
-- of { workspace = "1-5", monitorDescription = "..." } entries, edited
-- by Settings > Displays — replacing the old setup's hardcoded 1-5/6-10
-- split (docs/DECISIONS.md #15's manifest-layering spirit applied to
-- workspaces too).
--
-- Empty by default: with no rules, Hyprland's own automatic workspace
-- assignment applies, which is correct for a single-monitor M0 install.

local config = require("modules.config")

local rules = config.value("monitors.rules", {})

for _, rule in ipairs(rules) do
    if rule.workspace and rule.monitorDescription then
        hl.dsp.workspace.move({ workspace = rule.workspace, monitor = "desc:" .. rule.monitorDescription })
    end
end
