-- Every keybind's COMBO comes from config.json's keybinds table
-- (Settings > Keyboard's shortcut editor and Modules/Cheatsheet both
-- read the exact same table — see docs/WIDGETS.md's cheatsheet section
-- and docs/DECISIONS.md). What each action DOES is fixed here, in code,
-- since that's an architectural decision, not a per-user preference.
--
-- hl.bind(combo, dispatcher_descriptor) — dispatcher descriptors come
-- from hl.dsp.*, per wiki.hypr.land's 0.55+ Lua dispatcher reference.

local config = require("modules.config")

local function combo(action)
    return config.value("keybinds." .. action, nil)
end

-- Hyprland's own PATH often lacks ~/.bashrc. Scripts live in the checkout.
local modern = (os.getenv("HOME") or "") .. "/modern_dotfile/scripts/modern"

local function app_cmd(role, fallback)
    local id = config.value("apps.defaults." .. role, fallback) or fallback
    id = tostring(id):gsub("%.desktop$", "")
    return hl.dsp.exec_cmd("gtk-launch " .. id)
end

local function browser_incognito()
    local id = config.value("apps.defaults.browser", "vivaldi-stable.desktop") or "vivaldi-stable.desktop"
    local bin = tostring(id):gsub("%.desktop$", "")
    return hl.dsp.exec_cmd(bin .. " --incognito")
end

local function move_ws(n)
    return hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace " .. tostring(n))
end

-- action name -> dispatcher descriptor (or nil to skip if unbound)
-- Named config `modern` is ~/.config/quickshell/modern. Bare `qs ipc`
-- looks for a `default` instance that this desktop never starts.
local bindings = {
    launcher = hl.dsp.exec_cmd("qs -c modern ipc call launcher toggle"),
    powerMenu = hl.dsp.exec_cmd("qs -c modern ipc call powermenu toggle"),
    controlCenter = hl.dsp.exec_cmd("qs -c modern ipc call notifications toggle"),
    cheatsheet = hl.dsp.exec_cmd("qs -c modern ipc call cheatsheet toggle"),
    settings = hl.dsp.exec_cmd("qs -c modern ipc call settings open"),
    wallpaperPicker = hl.dsp.exec_cmd("qs -c modern ipc call wallpaper pick"),
    overview = hl.dsp.exec_cmd("qs -c modern ipc call overview toggle"),
    exitSession = hl.dsp.exit(),
    terminal = app_cmd("terminal", "kitty.desktop"),
    browser = app_cmd("browser", "vivaldi-stable.desktop"),
    browserIncognito = browser_incognito(),
    fileManager = app_cmd("fileManager", "org.kde.dolphin.desktop"),
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
    workspace1 = hl.dsp.focus({ workspace = 1 }),
    workspace2 = hl.dsp.focus({ workspace = 2 }),
    workspace3 = hl.dsp.focus({ workspace = 3 }),
    workspace4 = hl.dsp.focus({ workspace = 4 }),
    workspace5 = hl.dsp.focus({ workspace = 5 }),
    workspace6 = hl.dsp.focus({ workspace = 6 }),
    workspace7 = hl.dsp.focus({ workspace = 7 }),
    workspace8 = hl.dsp.focus({ workspace = 8 }),
    workspace9 = hl.dsp.focus({ workspace = 9 }),
    workspace10 = hl.dsp.focus({ workspace = 10 }),
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
    gameMode = hl.dsp.exec_cmd(modern .. " game mode toggle"),
    colorPicker = hl.dsp.exec_cmd("hyprpicker -a"),
    clipboardHistory = hl.dsp.exec_cmd(modern .. " clipboard show"),
}

for action, dispatcher in pairs(bindings) do
    local key = combo(action)
    if key then
        hl.bind(key, dispatcher)
    end
end

-- German: Shift+1 is "!" so SUPER+SHIFT+1 may miss the number row.
-- Physical keycodes 10–19 are the same on de/us.
local layout = tostring(config.value("input.kbLayout", "us") or "us")
if layout == "de" or layout:find("^de,") or layout:find(",de") then
    for n = 1, 9 do
        hl.bind("SUPER + code:" .. tostring(9 + n), hl.dsp.focus({ workspace = n }))
        hl.bind("SUPER + SHIFT + code:" .. tostring(9 + n), move_ws(n))
    end
    hl.bind("SUPER + code:19", hl.dsp.focus({ workspace = 10 }))
    hl.bind("SUPER + SHIFT + code:19", move_ws(10))
end

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
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +5%"), locked)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), locked)
