-- Every keybind's COMBO comes from config.json's keybinds table
-- (Settings > Keyboard's shortcut editor and Modules/Cheatsheet both
-- read the exact same table — see docs/WIDGETS.md's cheatsheet section
-- and docs/DECISIONS.md). What each action DOES is fixed here, in code,
-- since that's an architectural decision, not a per-user preference.
-- SUPER+T uses apps.defaults.terminal via modern-launch; SUPER+RETURN
-- is a hard-coded /usr/bin/kitty emergency when modern-launch is broken.
--
-- hl.bind(combo, dispatcher_descriptor) — dispatcher descriptors come
-- from hl.dsp.*, per wiki.hypr.land's 0.55+ Lua dispatcher reference.

local config = require("modules.config")
local paths = require("modules.paths")
local xkb = require("modules.xkb")

local function combo(action)
    return config.value("keybinds." .. action, nil)
end

local modern = paths.modern
local modern_launch = paths.modern_launch

local function app_cmd(role, fallback)
    local id = config.value("apps.defaults." .. role, fallback) or fallback
    id = tostring(id):gsub("%.desktop$", "")
    return hl.dsp.exec_cmd(modern_launch .. " " .. id)
end

local function browser_incognito()
    local id = config.value("apps.defaults.browser", "vivaldi-stable.desktop") or "vivaldi-stable.desktop"
    id = tostring(id):gsub("%.desktop$", "")
    local flag = "--incognito"
    local lower = string.lower(id)
    if lower:find("firefox", 1, true) or lower:find("librewolf", 1, true) then
        flag = "--private-window"
    end
    return hl.dsp.exec_cmd(modern_launch .. " " .. id .. " " .. flag)
end

local workspaces = require("modules.workspaces")

-- Pin-then-focus so SUPER+N in fixed mode jumps to the assigned
-- monitor instead of spawning that workspace on the focused display.
local function focus_ws(n)
    return function()
        workspaces.focus(n)
    end
end

local function move_ws(n)
    return function()
        workspaces.move_window(n)
    end
end

local function number_row_code(n)
    return xkb.number_row_code(n)
end

local function default_number_combo(n, shift)
    return xkb.default_number_combo(n, shift)
end

-- Bare path — a wrapped sh -lc here broke emergency terminal binds on main.
-- colors.conf is globincluded from kitty.conf so a missing theme is not fatal.
local emergency_kitty = hl.dsp.exec_cmd("/usr/bin/kitty")

-- action name -> dispatcher descriptor (or nil to skip if unbound)
-- Named config `modern` is ~/.config/quickshell/modern. Bare `qs ipc`
-- looks for a `default` instance that this desktop never starts.
local bindings = {
    launcher = hl.dsp.exec_cmd("qs -c modern ipc call launcher toggle"),
    aiChat = hl.dsp.exec_cmd("qs -c modern ipc call ai toggle"),
    powerMenu = hl.dsp.exec_cmd("qs -c modern ipc call powermenu toggle"),
    controlCenter = hl.dsp.exec_cmd("qs -c modern ipc call notifications toggle"),
    lockScreen = hl.dsp.exec_cmd("qs -c modern ipc call session lock"),
    cheatsheet = hl.dsp.exec_cmd("qs -c modern ipc call cheatsheet toggle"),
    settings = hl.dsp.exec_cmd("qs -c modern ipc call settings toggle"),
    wallpaperPicker = hl.dsp.exec_cmd("qs -c modern ipc call wallpaper toggle"),
    taskbar = hl.dsp.exec_cmd("qs -c modern ipc call taskbar toggle"),
    overview = hl.dsp.exec_cmd("qs -c modern ipc call overview toggle"),
    exitSession = hl.dsp.exit(),
    terminal = app_cmd("terminal", "kitty.desktop"),
    browser = app_cmd("browser", "vivaldi-stable.desktop"),
    browserIncognito = browser_incognito(),
    fileManager = app_cmd("fileManager", "org.gnome.Nautilus.desktop"),
    spotify = hl.dsp.exec_cmd("spotify-launcher"),
    -- killactive would close the window behind layer-shell HUD/popups.
    -- modern window close dismisses those first, then killactive.
    closeWindow = hl.dsp.exec_cmd(modern .. " window close"),
    fullscreen = hl.dsp.window.fullscreen(),
    toggleFloating = hl.dsp.window.float({ action = "toggle" }),
    pseudoTile = hl.dsp.window.pseudo(),
    toggleSplit = hl.dsp.layout("togglesplit"),
    moveFocusLeft = hl.dsp.focus({ direction = "l" }),
    moveFocusRight = hl.dsp.focus({ direction = "r" }),
    moveFocusUp = hl.dsp.focus({ direction = "u" }),
    moveFocusDown = hl.dsp.focus({ direction = "d" }),
    -- Directional window swap-in-layout isn't yet in the confirmed
    -- hl.dsp table (see docs/TROUBLESHOOTING.md) — hyprctl fallback,
    -- functionally identical to the classic movewindow dispatcher.
    moveWindowLeft = hl.dsp.exec_cmd("hyprctl dispatch movewindow l"),
    moveWindowRight = hl.dsp.exec_cmd("hyprctl dispatch movewindow r"),
    moveWindowUp = hl.dsp.exec_cmd("hyprctl dispatch movewindow u"),
    moveWindowDown = hl.dsp.exec_cmd("hyprctl dispatch movewindow d"),
    workspace1 = focus_ws(1),
    workspace2 = focus_ws(2),
    workspace3 = focus_ws(3),
    workspace4 = focus_ws(4),
    workspace5 = focus_ws(5),
    workspace6 = focus_ws(6),
    workspace7 = focus_ws(7),
    workspace8 = focus_ws(8),
    workspace9 = focus_ws(9),
    workspace10 = focus_ws(10),
    moveToWorkspace1 = move_ws(1),
    moveToWorkspace2 = move_ws(2),
    moveToWorkspace3 = move_ws(3),
    moveToWorkspace4 = move_ws(4),
    moveToWorkspace5 = move_ws(5),
    moveToWorkspace6 = move_ws(6),
    moveToWorkspace7 = move_ws(7),
    moveToWorkspace8 = move_ws(8),
    moveToWorkspace9 = move_ws(9),
    moveToWorkspace10 = move_ws(10),
    screenshotRegion = hl.dsp.exec_cmd(modern .. " screenshot region"),
    screenshotWindow = hl.dsp.exec_cmd(modern .. " screenshot window"),
    screenshotFull = hl.dsp.exec_cmd(modern .. " screenshot full"),
    colorPicker = hl.dsp.exec_cmd("hyprpicker -a"),
    filePreview = hl.dsp.exec_cmd(modern .. " filepreview"),
}

-- SPACE is a typing key. Non-consuming so fields still receive it.
-- filepreview.sh no-ops in Nautilus (Sushi owns Space there) and only
-- opens Quick Look in Dolphin.
local function bind_opts(action)
    if action == "filePreview" then
        return { non_consuming = true }
    end
    return nil
end

local function bind_combo(combo, dispatcher, action)
    local opts = bind_opts(action)
    if opts then
        hl.bind(combo, dispatcher, opts)
    else
        hl.bind(combo, dispatcher)
    end
end

for action, dispatcher in pairs(bindings) do
    local key = combo(action)
    if key then
        local skip = false
        for n = 1, 10 do
            if action == ("workspace" .. n) and key == default_number_combo(n, false) then
                bind_combo("SUPER + " .. number_row_code(n), dispatcher, action)
                skip = true
            elseif action == ("moveToWorkspace" .. n) and key == default_number_combo(n, true) then
                bind_combo("SUPER + SHIFT + " .. number_row_code(n), dispatcher, action)
                skip = true
            end
        end
        local named = xkb.named[action]
        if named and key == named.combo then
            bind_combo(named.bind, dispatcher, action)
            skip = true
        end
        if not skip then
            bind_combo(key, dispatcher, action)
        end
    end
end

-- Emergency terminal only — does not replace keybinds.terminal / modern-launch.
hl.bind("SUPER + RETURN", emergency_kitty)

-- Power menu (SUPER+M) needs the shell. This always ends the compositor.
if not combo("exitSession") then
    hl.bind("SUPER + SHIFT + M", hl.dsp.exit())
end

-- Mouse: drag / resize / workspace on this monitor. Not in the editor.
if hl.dsp.window and hl.dsp.window.drag then
    hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
end
if hl.dsp.window and hl.dsp.window.resize then
    hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
end
hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd("hyprctl dispatch workspace m-1"), { mouse = true })
hl.bind("SUPER + mouse_up", hl.dsp.exec_cmd("hyprctl dispatch workspace m+1"), { mouse = true })

-- Media/backlight keys are hardware-fixed X11 keysyms, not user-remapped
-- via the shortcut editor, so they're bound directly rather than through
-- config.json — matching the ArchWiki's documented pattern.
local locked = { repeating = true, locked = true }
local locked_once = { locked = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), locked)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), locked)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked_once)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked_once)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), locked_once)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked_once)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), locked_once)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), locked_once)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(modern .. " brightness up"), locked)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(modern .. " brightness down"), locked)
