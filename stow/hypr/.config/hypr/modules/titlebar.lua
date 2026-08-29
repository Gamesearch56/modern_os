-- SSD titlebars via hyprbars. Enabled from config.json windows.titlebar
-- *and* only when the plugin is actually loaded — hl.config({ plugin =
-- { hyprbars = … }}) is an unknown key and fills the error overlay if
-- we apply it at parse time before hyprpm has loaded the .so.
-- Traffic-light hues are OS window-control affordances, not MD3 roles
-- (docs/DECISIONS.md). Surface colors come from modules/colors.lua.

local config = require("modules.config")
local colors = require("modules.colors")

if not config.value("windows.titlebar", true) then
    return
end

local bars = hl.plugin and hl.plugin.hyprbars
if not bars then
    return
end

local font = config.value("typography.ui", "Inter")
local surface = (type(colors) == "table" and colors.hyprbars) or {}

hl.config({
    plugin = {
        hyprbars = {
            bar_height = 32,
            bar_padding = 8,
            bar_button_padding = 4,
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            bar_blur = true,
            bar_text_font = font,
            bar_text_size = 14,
            bar_text_align = "left",
            bar_buttons_alignment = "left",
            bar_color = surface.bar_color,
            ["col.text"] = surface["col.text"],
        },
    },
})

if bars.add_button then
    bars.add_button({
        bg_color = "rgb(c42b1c)",
        fg_color = "rgb(ffffff)",
        size = 12,
        icon = "",
        action = "hyprctl dispatch 'hl.dsp.window.close()'",
    })
    bars.add_button({
        bg_color = "rgb(30d158)",
        fg_color = "rgb(ffffff)",
        size = 12,
        icon = "",
        action = "hyprctl dispatch 'hl.dsp.window.float({ action = \"toggle\" })'",
    })
    bars.add_button({
        bg_color = "rgb(ff9f0a)",
        fg_color = "rgb(ffffff)",
        size = 12,
        icon = "",
        action = "hyprctl dispatch 'hl.dsp.window.fullscreen()'",
    })
end

hl.window_rule({
    name = "hyprbars-fullscreen-no-bar",
    match = { fullscreen = true },
    ["hyprbars:no_bar"] = true,
})

-- Settings and picker windows draw their own close; a hyprbars button
-- on top of that is a second X. Applied here so the plugin is loaded.
local chrome = {
    "modern.settings",
    "modern.cheatsheet",
    "modern.overview",
}
for _, title in ipairs(chrome) do
    hl.window_rule({
        name = "hyprbars-nobar-" .. title,
        match = { title = title },
        ["hyprbars:no_bar"] = true,
    })
end
