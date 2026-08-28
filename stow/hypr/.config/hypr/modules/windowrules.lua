-- Window rules, driven entirely by config.json's windowRules array —
-- Settings > Windows' rule table (match on class/title, then
-- float/size/position/workspace/opacity/...), replacing hand-edited Lua
-- (docs/ARCHITECTURE.md's "two data flows" — Settings never writes Lua).
--
-- Effect names must match 0.56's WINDOW_RULE_EFFECT_DESCS exactly:
-- dim_around (not dimaround), size as {w, h}, opacity as a string.
-- Plugin effects (hyprbars:no_bar, …) are unknown until hyprbars is
-- loaded — same gate as modules/titlebar.lua.

local config = require("modules.config")

local function hyprbars_loaded()
    return hl.plugin and hl.plugin.hyprbars ~= nil
end

local function vec2(v)
    if type(v) ~= "string" then
        return v
    end
    local a, b = v:match("^(%S+)%s+(%S+)$")
    if not a then
        return v
    end
    return { tonumber(a) or a, tonumber(b) or b }
end

local function normalize(rule)
    local out = {}
    for k, v in pairs(rule) do
        local key = k
        if key == "dimaround" then
            key = "dim_around"
        end
        local plugin_effect = type(key) == "string" and key:sub(1, 9) == "hyprbars:"
        if not plugin_effect or hyprbars_loaded() then
            if key == "size" or key == "move" or key == "max_size" or key == "min_size" then
                out[key] = vec2(v)
            elseif key == "opacity" and type(v) == "number" then
                out[key] = tostring(v) .. " override"
            else
                out[key] = v
            end
        end
    end
    return out
end

local function apply(rule)
    if not rule or not rule.match then
        return
    end
    hl.window_rule(normalize(rule))
end

for _, rule in ipairs(config.value("windowRules", {})) do
    apply(rule)
end

-- One default, kept even with an empty user rule list: JetBrains IDEs
-- have well-documented Wayland/XWayland focus-stealing issues (see
-- docs/DECISIONS.md's audit and the ArchWiki Hyprland troubleshooting
-- section) — this is cheap insurance, not a personal preference.
apply({
    name = "xwayland-no-initial-focus",
    match = { xwayland = true },
    no_initial_focus = true,
})

-- hyprpolkitagent has no .desktop file; Wayland app_id is the binary
-- name or the QApplication name. Float+center so the prompt is not
-- tiled behind the requesting window. Rounding follows decoration.
apply({
    name = "polkit-auth-dialog",
    match = { class = "hyprpolkitagent|hyprland-polkit-agent" },
    float = true,
    center = true,
})

apply({
    name = "modern-settings",
    match = { title = "modern.settings" },
    float = true,
    center = true,
    size = { 1040, 720 },
    ["hyprbars:no_bar"] = true,
    opaque = true,
})

local overlay_windows = {
    { name = "modern-wallpaper", title = "modern.wallpaper", size = { 920, 640 } },
    { name = "modern-cheatsheet", title = "modern.cheatsheet", size = { 980, 680 } },
    { name = "modern-powermenu", title = "modern.powermenu", size = { 420, 560 } },
    { name = "modern-launcher", title = "modern.launcher", size = { 560, 520 } },
    { name = "modern-overview", title = "modern.overview", size = { 920, 640 } },
}

for _, w in ipairs(overlay_windows) do
    apply({
        name = w.name,
        match = { title = w.title },
        float = true,
        center = true,
        size = w.size,
        dim_around = true,
        ["hyprbars:no_bar"] = true,
        opaque = true,
    })
end
