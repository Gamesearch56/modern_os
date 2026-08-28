-- Window rules, driven entirely by config.json's windowRules array —
-- Settings > Windows' rule table (match on class/title, then
-- float/size/position/workspace/opacity/...), replacing hand-edited Lua
-- (docs/ARCHITECTURE.md's "two data flows" — Settings never writes Lua).
--
-- Each entry: { name?, match = { class=, title=, xwayland= }, ...effects }
-- effects map 1:1 onto hl.window_rule()'s keys — see
-- wiki.hypr.land/Configuring/Basics/Window-Rules for the full effect
-- list (float, tile, fullscreen, move, size, center, pseudo, monitor,
-- workspace, no_initial_focus, pin, group, content, no_close_for, ...).

local config = require("modules.config")

local rules = config.value("windowRules", {})

for _, rule in ipairs(rules) do
    if rule.match then
        hl.window_rule(rule)
    end
end

-- One default, kept even with an empty user rule list: JetBrains IDEs
-- have well-documented Wayland/XWayland focus-stealing issues (see
-- docs/DECISIONS.md's audit and the ArchWiki Hyprland troubleshooting
-- section) — this is cheap insurance, not a personal preference.
hl.window_rule({
    name = "xwayland-no-initial-focus",
    match = { xwayland = true },
    no_initial_focus = true,
})
