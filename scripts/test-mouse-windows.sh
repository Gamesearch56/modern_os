#!/usr/bin/env bash
# Side- and middle-button window controls: Lua state machine against a mock hl,
# the replay helper's argument guard, and the Settings/cheatsheet wiring.
# scripts/test-mouse-windows-live.py drives the real compositor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR="$ROOT/stow/hypr/.config/hypr"
QS="$ROOT/stow/shell/.config/quickshell/modern"
DEFAULT="$ROOT/stow/modern/.config/modern/config.default.json"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
FAIL=0

err() { printf 'test-mouse-windows: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-mouse-windows: ok %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
LUA="$(command -v lua5.4 || command -v lua || true)"
[ -n "$LUA" ] || { echo "lua required" >&2; exit 1; }

for f in mouse_windows game_match games; do
    if "$LUA" -e "assert(loadfile('$HYPR/modules/$f.lua'))"; then
        ok "$f.lua parses"
    else
        err "$f.lua does not parse"
    fi
done

if grep -A1 'require("modules.keybinds")' "$HYPR/hyprland.lua" | grep -q 'require("modules.mouse_windows")'; then
    ok "hyprland.lua loads mouse_windows after keybinds"
else
    err "hyprland.lua must require modules.mouse_windows right after modules.keybinds"
fi
if grep -q 'require("modules.game_match")' "$HYPR/modules/games.lua"; then
    ok "games.lua uses the shared game matcher"
else
    err "games.lua must use modules.game_match"
fi

out="$(cd "$HYPR" && "$LUA" - "$ROOT" <<'LUA'
local root = arg[1]
local log, binds, unbound, timers = {}, {}, {}, {}
local threshold
local active = { class = "vivaldi-stable", title = "Page", fullscreen = 0,
    at = { x = 0, y = 0 }, size = { x = 800, y = 600 } }
local cursor = { x = 100, y = 100 }
local handlers = {}
hl = {
    dsp = {
        exec_cmd = function(c) return { exec = c } end,
        window = { drag = function() return "drag" end, resize = function() return "resize" end,
            close = function() return "close" end, float = function() return "float" end,
            fullscreen = function() return "fullscreen" end },
    },
    config = function(t) threshold = t.binds.drag_threshold end,
    timer = function(fn, o) timers[#timers + 1] = { fn = fn, ms = o.timeout } end,
    bind = function(key, fn, opts)
        binds[#binds + 1] = { key = key, fn = fn, opts = opts or {} }
    end,
    unbind = function(key)
        unbound[#unbound + 1] = key
        local keep = {}
        for _, b in ipairs(binds) do if b.key ~= key then keep[#keep + 1] = b end end
        binds = keep
    end,
    dispatch = function(d) log[#log + 1] = "dispatch:" .. (type(d) == "table" and d.exec or tostring(d)) end,
    exec_cmd = function(c) log[#log + 1] = "exec:" .. c end,
    get_active_window = function() return active end,
    get_cursor_pos = function() return cursor end,
    get_layers = function() return { { mapped = true, layer = 2, x = 0, y = 700, w = 800, h = 52 } } end,
    on = function(ev, cb) handlers[ev] = cb end,
}
package.preload["modules.config"] = function()
    return { value = function(_, fallback) return fallback end }
end
package.preload["modules.paths"] = function()
    return { modern = "/nonexistent/modern", scripts = "/repo/scripts" }
end
package.preload["modules.game_match"] = function()
    return { is_game = function(w) return w.class == "wow" end }
end
dofile(root .. "/stow/hypr/.config/hypr/modules/mouse_windows.lua")

local function fire(key, kind)
    for _, b in ipairs(binds) do
        local o = b.opts
        local match = (kind == "press" and not o.release and not o.click and not o.mouse)
            or (kind == "release" and o.release and not o.click)
            or (kind == "click" and o.click)
        if b.key == key and match and type(b.fn) == "function" then b.fn() end
    end
end
local function count(kind)
    local n = 0
    for _, b in ipairs(binds) do
        if (kind == "drag" and b.fn == "drag") or (kind == "resize" and b.fn == "resize") then n = n + 1 end
    end
    return n
end
local function report(name) print(name .. " " .. table.concat(log, " ")); log = {} end
local function has(key)
    for _, b in ipairs(binds) do if b.key == key then return true end end
    return false
end
local function consuming()
    local n = 0
    for _, b in ipairs(binds) do if not b.opts.non_consuming then n = n + 1 end end
    return n
end
local function run_timers()
    local t = timers; timers = {}
    for _, x in ipairs(t) do x.fn() end
end

print("threshold=" .. tostring(threshold))
print("binds " .. #binds .. " drag=" .. count("drag") .. " resize=" .. count("resize"))
print("middle-idle " .. tostring(has("mouse:274")))
fire("mouse:275", "press")
print("gate-press threshold=" .. threshold .. " timer=" .. tostring(timers[#timers] and timers[#timers].ms))
run_timers()
print("gate-held threshold=" .. threshold)
fire("mouse:275", "release"); fire("mouse:275", "click"); log = {}
fire("mouse:275", "press"); fire("mouse:275", "release"); fire("mouse:275", "click")
fire("mouse:275", "press"); timers[1].fn(); table.remove(timers, 1)
print("gate-stale threshold=" .. threshold)
run_timers(); fire("mouse:275", "release"); fire("mouse:275", "click"); log = {}
fire("mouse:275", "press"); fire("mouse:275", "release"); fire("mouse:275", "click"); report("back-click")
fire("mouse:276", "press"); fire("mouse:276", "release"); fire("mouse:276", "click"); report("forward-click")
fire("mouse:275", "press"); fire("mouse:276", "press"); fire("mouse:276", "release"); fire("mouse:276", "click")
fire("mouse:275", "release"); fire("mouse:275", "click"); report("chord")
fire("mouse:276", "press"); fire("mouse:275", "press"); fire("mouse:275", "release"); fire("mouse:275", "click")
fire("mouse:276", "release"); fire("mouse:276", "click"); report("chord-reverse")
fire("mouse:275", "press"); fire("mouse:275", "release"); fire("mouse:275", "click"); report("after-chord")
cursor = { x = 100, y = 720 }
fire("mouse:275", "press"); fire("mouse:275", "release"); fire("mouse:275", "click"); report("over-layer")
cursor = { x = 100, y = 100 }
fire("mouse:275", "press"); print("middle-held " .. tostring(has("mouse:274")))
fire("mouse:274", "press"); fire("mouse:275", "release"); fire("mouse:275", "click")
print("middle-released " .. tostring(has("mouse:274"))); report("back-middle")
fire("mouse:276", "press"); fire("mouse:274", "press"); fire("mouse:276", "release"); fire("mouse:276", "click")
report("forward-middle")
active.fullscreen = 2; handlers["window.fullscreen"](active)
print("fullscreen binds " .. #binds .. " consuming=" .. consuming())
fire("mouse:276", "press"); fire("mouse:274", "press"); fire("mouse:276", "release"); fire("mouse:276", "click")
report("fullscreen-forward-middle")
fire("mouse:276", "press"); fire("mouse:276", "release"); fire("mouse:276", "click"); report("fullscreen-forward")
active.fullscreen = 0; handlers["window.active"](active)
print("windowed binds " .. #binds)
active = { class = "wow", title = "World of Warcraft", fullscreen = 0, at = { x = 0, y = 0 }, size = { x = 800, y = 600 } }
handlers["window.active"](active)
print("game binds " .. #binds .. " consuming=" .. consuming())
LUA
)" || { err "mock run failed"; printf '%s\n' "$out" >&2; }

expect() {
    if printf '%s\n' "$out" | grep -qxF -- "$1"; then ok "$2"; else err "$2 (want: $1)"; printf '%s\n' "$out" >&2; fi
}
expect "binds 8 drag=1 resize=1" "both side buttons get press, release, drag/resize and click binds"
expect "back-click exec:/repo/scripts/mouse-replay 275" "a back click is replayed as button 275"
expect "forward-click exec:/repo/scripts/mouse-replay 276" "a forward click is replayed as button 276"
expect "chord dispatch:close" "back held + forward closes once, nothing replayed"
expect "chord-reverse dispatch:close" "forward held + back closes once, nothing replayed"
expect "after-chord exec:/repo/scripts/mouse-replay 275" "the next click after a chord is a normal click"
expect "over-layer " "a click over the bar or dock is not replayed into the window"
expect "threshold=10" "drag threshold separates a held click from a drag"
expect "middle-idle false" "the middle button is left to apps while no side button is held"
expect "gate-press threshold=100000 timer=250" "a fresh side press cannot start a drag"
expect "gate-held threshold=10" "holding the side button arms the drag"
expect "gate-stale threshold=100000" "an old hold timer does not cut a newer press short"
expect "middle-held true" "holding a side button takes the middle button"
expect "middle-released false" "releasing the side button gives the middle button back"
expect "back-middle dispatch:float" "back + middle toggles floating, nothing replayed"
expect "forward-middle dispatch:fullscreen" "forward + middle toggles fullscreen, nothing replayed"
expect "fullscreen binds 4 consuming=0" "fullscreen windows get the side buttons untouched"
expect "fullscreen-forward-middle dispatch:fullscreen" "forward + middle leaves fullscreen"
expect "fullscreen-forward " "in fullscreen a forward click is not replayed twice"
expect "windowed binds 8" "leaving fullscreen binds the side buttons again"
expect "game binds 4 consuming=0" "game windows get the side buttons untouched"

set +e
"$ROOT/scripts/mouse-replay" 272 2>/dev/null; rc_bad=$?
"$ROOT/scripts/mouse-replay" '275;x' 2>/dev/null; rc_inj=$?
set -e
if [ "$rc_bad" -eq 2 ] && [ "$rc_inj" -eq 2 ]; then
    ok "mouse-replay only accepts the side buttons"
else
    err "mouse-replay must reject anything but 275/276"
fi

if [ "$(jq -r '.input.mouseSideButtons' "$DEFAULT")" = "true" ]; then
    ok "side buttons on by default"
else
    err "config.default.json input.mouseSideButtons must be true"
fi
if grep -q 'property bool mouseSideButtons: true' "$QS/Commons/Config.qml"; then
    ok "Config.qml fallback"
else
    err "Config.qml needs input.mouseSideButtons"
fi
if grep -q 'job.path === "input.mouseSideButtons"' "$QS/Services/ConfigWrite.qml"; then
    ok "toggling reloads Hyprland"
else
    err "ConfigWrite must reload Hyprland for input.mouseSideButtons"
fi
if grep -q 'ConfigWrite.set("input.mouseSideButtons"' "$QS/Modules/Settings/sections/keyboard/Section.qml"; then
    ok "Settings switch"
else
    err "Keyboard section needs the side-button switch"
fi
if grep -q 'onMiddleClicked: item.clickClose()' "$QS/Modules/Bar/widgets/taskbar/Entry.qml"; then
    ok "middle click closes from Applications"
else
    err "taskbar Entry must close on middle click"
fi

for f in "$EN" "$DE"; do
    for k in settings.fields.mouseSideButtons settings.hints.mouseSideButtons \
        cheatsheet.action.mouseMoveSide cheatsheet.action.mouseResizeSide \
        cheatsheet.action.mouseCloseSide cheatsheet.action.mouseCloseApp \
        cheatsheet.action.mouseFloatSide cheatsheet.action.mouseFullscreenSide \
        cheatsheet.mouseHint; do
        [ "$(jq -r ".$k // empty" "$f")" != "" ] || err "$(basename "$f") missing $k"
    done
done
ok "translations"

for a in mouseMoveSide mouseResizeSide mouseCloseSide mouseFloatSide mouseFullscreenSide mouseCloseApp; do
    grep -q "action: \"$a\"" "$QS/Services/CheatsheetModel.qml" || err "cheatsheet missing $a"
done
if grep -q 'key: "cheatsheet.mouseHint"' "$QS/Modules/Cheatsheet/Binds.qml"; then
    ok "cheatsheet explains MB4/MB5 under Mouse"
else
    err "cheatsheet Mouse page needs cheatsheet.mouseHint"
fi
if grep -q 'g.side && !side' "$QS/Services/CheatsheetModel.qml"; then
    ok "cheatsheet hides side rows when switched off"
else
    err "cheatsheet must hide side rows when off"
fi

exit "$FAIL"
