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

-- Touchpad gestures: 3-finger swipe switches workspaces, the most common
-- Hyprland default.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Three fingers up and down share one vertical gesture so the overview
-- can follow the fingers in either direction. A finished up/down action
-- only fires after the hand lifts, which cannot fade with the swipe.
-- Travel is upward pixels (Hyprland's Y delta is negative when the
-- fingers move up). The shell adds that to the reveal it already has.
local overview_travel = 0
local overview_sent = nil
local overview_velocity = 0
local overview_last = 0

local function overview_now(event)
    if event and event.time_ms then
        return event.time_ms
    end
    return math.floor((os.clock() or 0) * 1000)
end

local function overview_up(event)
    local delta = event and event.delta
    if type(delta) ~= "table" then
        return 0
    end
    return -(delta.y or 0)
end

local function overview_emit(payload)
    hl.dispatch(hl.dsp.event("modernoverview," .. payload))
end

hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = {
        start = function(event)
            overview_travel = overview_up(event)
            overview_velocity = 0
            overview_last = overview_now(event)
            overview_sent = math.floor(overview_travel + 0.5)
            overview_emit("begin")
            if overview_sent ~= 0 then
                overview_emit(string.format("move,%d,0", overview_sent))
            end
        end,
        update = function(event)
            local step = overview_up(event)
            local now = overview_now(event)
            local elapsed = now - overview_last
            if elapsed <= 0 then
                elapsed = 1
            end
            overview_last = now
            overview_velocity = overview_velocity * 0.6 + (step / elapsed * 1000) * 0.4
            overview_travel = overview_travel + step
            local rounded = math.floor(overview_travel + 0.5)
            if rounded == overview_sent then
                return
            end
            overview_sent = rounded
            overview_emit(string.format("move,%d,%d", rounded, math.floor(overview_velocity + 0.5)))
        end,
        finish = function(event)
            local cancelled = event and event.cancelled and 1 or 0
            overview_emit(string.format("end,%d,%d", cancelled, math.floor(overview_velocity + 0.5)))
        end,
    },
})
