-- Side mouse buttons control windows without the keyboard:
-- hold back + move = move window, hold forward + move = resize,
-- back + forward = close (same path as SUPER+Q),
-- back + middle = toggle floating, forward + middle = toggle fullscreen.
-- A click is replayed to the window as the real button
-- (scripts/mouse-replay), so back/forward keep working in every app.
-- Replaying must happen outside the bind: send_shortcut from inside a
-- click/release bind only delivers the key-up.
-- Apps act on the press (Chromium navigates on it), so the press can
-- never be passed through while a drag is still possible.
-- Games and fullscreen windows get the side buttons untouched, since a
-- held side button (push-to-talk, game binds) only survives as a click
-- here. Forward + middle still toggles fullscreen there, so a game can
-- be taken out of fullscreen with the mouse alone.
local config = require("modules.config")
local paths = require("modules.paths")
local game_match = require("modules.game_match")

if config.value("input.mouseSideButtons", true) == false then
    return
end

local BACK, FORWARD, MIDDLE = 275, 276, 274
-- Pixels the pointer may wander before a held press counts as a drag.
local DRAG_THRESHOLD = 10
-- A press shorter than this is a click however far the hand moved:
-- side buttons are often clicked while the mouse is still travelling.
local HOLD_MS = 250
local NO_DRAG = 100000
local TOP_LAYER = 2

hl.config({ binds = { drag_threshold = DRAG_THRESHOLD } })

local replay_cmd = paths.scripts .. "/mouse-replay"

local close_cmd
do
    local f = io.open(paths.modern, "r")
    if f then
        f:close()
        close_cmd = hl.dsp.exec_cmd(paths.modern .. " window close")
    else
        close_cmd = hl.dsp.window.close()
    end
end
local chord_cmd = {
    [BACK] = hl.dsp.window.float({ action = "toggle" }),
    [FORWARD] = hl.dsp.window.fullscreen(),
}

local held = { [BACK] = false, [FORWARD] = false }
local swallow = { [BACK] = false, [FORWARD] = false }
local mode = nil
local middle_bound = false
local presses = 0

local function inside(p, x, y, w, h)
    return p.x >= x and p.y >= y and p.x < x + w and p.y < y + h
end

-- The replayed button goes to the focused window. Over the bar, dock or
-- a shell overlay it would land in the window underneath instead.
local function cursor_on(w)
    local p = hl.get_cursor_pos and hl.get_cursor_pos()
    if not p or not w or type(w.at) ~= "table" or type(w.size) ~= "table" then
        return false
    end
    if not inside(p, w.at.x or w.at[1], w.at.y or w.at[2], w.size.x or w.size[1], w.size.y or w.size[2]) then
        return false
    end
    local layers = hl.get_layers and hl.get_layers() or {}
    for i = 1, #layers do
        local l = layers[i]
        if l.mapped and (l.layer or 0) >= TOP_LAYER and inside(p, l.x, l.y, l.w, l.h) then
            return false
        end
    end
    return true
end

local function replay(code)
    if cursor_on(hl.get_active_window()) then
        hl.exec_cmd(replay_cmd .. " " .. code)
    end
end

-- Middle is only taken while a side button is held, so middle click,
-- paste and middle drag stay with the app the rest of the time.
local function on_middle()
    for code, cmd in pairs(chord_cmd) do
        if held[code] then
            swallow[code] = true
            hl.dispatch(cmd)
            return
        end
    end
end

local function sync_middle()
    local want = held[BACK] or held[FORWARD]
    if want and not middle_bound then
        hl.bind("mouse:" .. MIDDLE, on_middle)
        middle_bound = true
    elseif not want and middle_bound then
        hl.unbind("mouse:" .. MIDDLE)
        middle_bound = false
    end
end

local function hold_gate()
    presses = presses + 1
    local mine = presses
    hl.config({ binds = { drag_threshold = NO_DRAG } })
    hl.timer(function()
        if mine == presses then
            hl.config({ binds = { drag_threshold = DRAG_THRESHOLD } })
        end
    end, { timeout = HOLD_MS, type = "oneshot" })
end

local function on_click(code, other)
    if swallow[code] then
        swallow[code] = false
        return
    end
    if held[other] then
        swallow[other] = true
        hl.dispatch(close_cmd)
        return
    end
    replay(code)
end

local function track(code, consuming)
    local key = "mouse:" .. code
    hl.bind(key, function()
        held[code] = true
        swallow[code] = false
        if consuming then
            hold_gate()
        end
        sync_middle()
    end, { non_consuming = true })
    hl.bind(key, function()
        held[code] = false
        sync_middle()
    end, { release = true, non_consuming = true })
end

local function bind_full(code, other, dispatcher)
    track(code, true)
    local key = "mouse:" .. code
    hl.bind(key, dispatcher, { mouse = true })
    hl.bind(key, function() on_click(code, other) end, { click = true })
end

local function clear()
    hl.unbind("mouse:" .. BACK)
    hl.unbind("mouse:" .. FORWARD)
    if middle_bound then
        hl.unbind("mouse:" .. MIDDLE)
        middle_bound = false
    end
    held[BACK], held[FORWARD] = false, false
    swallow[BACK], swallow[FORWARD] = false, false
    presses = presses + 1
    hl.config({ binds = { drag_threshold = DRAG_THRESHOLD } })
end

local function set_mode(want)
    if mode == want then
        return
    end
    if mode then
        clear()
    end
    mode = want
    if want == "full" then
        bind_full(BACK, FORWARD, hl.dsp.window.drag())
        bind_full(FORWARD, BACK, hl.dsp.window.resize())
    else
        track(BACK, false)
        track(FORWARD, false)
    end
end

local function native(w)
    if not w then
        return false
    end
    if (tonumber(w.fullscreen) or 0) >= 2 then
        return true
    end
    return game_match.is_game(w)
end

local function refresh()
    set_mode(native(hl.get_active_window()) and "native" or "full")
end

set_mode("full")

if hl.on then
    local function soon()
        pcall(refresh)
    end
    hl.on("window.active", soon)
    hl.on("window.fullscreen", soon)
    hl.on("window.title", soon)
    hl.on("window.class", soon)
    hl.on("window.close", soon)
end
