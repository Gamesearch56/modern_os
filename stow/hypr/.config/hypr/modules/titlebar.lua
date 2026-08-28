-- SSD titlebars via hyprbars. Enabled from config.json windows.titlebar.
-- Traffic-light hues are OS window-control affordances, not MD3 roles
-- (docs/DECISIONS.md). Close still uses the error token from colors.lua.

local config = require("modules.config")

if not config.value("windows.titlebar", true) then
    return
end

local rounding = math.floor(8 * (config.value("design.cornerRounding", 1.0)))
local font = config.value("typography.ui", "Inter")

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
        },
    },
})

if hl.plugin and hl.plugin.hyprbars and hl.plugin.hyprbars.add_button then
    local bars = hl.plugin.hyprbars
    bars.add_button({
        icon = "",
        onclick = "killactive",
        col = { idle = 0xffc42b1c, hover = 0xffe64539 },
    })
    bars.add_button({
        icon = "",
        onclick = "togglefloating",
        col = { idle = 0xff30d158, hover = 0xff3ee66e },
    })
    bars.add_button({
        icon = "",
        onclick = "fullscreen",
        col = { idle = 0xffff9f0a, hover = 0xffffb340 },
    })
end

hl.window_rule({
    name = "hyprbars-fullscreen-no-bar",
    match = { fullscreen = true },
    ["hyprbars:no_bar"] = true,
})
