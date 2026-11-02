-- Keyboard/mouse/touchpad input, sourced from config.json's future
-- Settings > Keyboard section (layout/variant/repeat rate — see
-- docs/ARCHITECTURE.md). Ships sane defaults so a fresh install doesn't
-- need to touch this file before Settings > Keyboard exists.

local config = require("modules.config")

hl.config({
    input = {
        kb_layout = config.value("input.kbLayout", "us"),
        kb_variant = config.value("input.kbVariant", ""),
        repeat_rate = config.value("input.repeatRate", 25),
        repeat_delay = config.value("input.repeatDelay", 600),
        numlock_by_default = config.value("input.numlockOnBoot", false),
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 1.0,
        },
    },
})

-- Touchpad gestures: 3-finger swipe switches workspaces, matching the
-- most common Hyprland default and the audited system's laptop use.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
-- 3-finger swipe up opens the window overview (SUPER+Tab), down closes
-- it, like Mission Control. open/hide rather than toggle so a repeated
-- swipe never closes what the user just opened.
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd("qs -c modern ipc call overview open")
    end,
})
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd("qs -c modern ipc call overview hide")
    end,
})
