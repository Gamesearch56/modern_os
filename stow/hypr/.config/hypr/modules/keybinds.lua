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

-- action name -> dispatcher descriptor (or nil to skip if unbound)
local bindings = {
    launcher = hl.dsp.exec_cmd("modern launcher toggle"),
    powerMenu = hl.dsp.exec_cmd("modern powermenu toggle"),
    cheatsheet = hl.dsp.exec_cmd("modern cheatsheet toggle"),
    settings = hl.dsp.exec_cmd("modern settings open"),
    wallpaperPicker = hl.dsp.exec_cmd("modern wallpaper picker"),
    overview = hl.dsp.exec_cmd("modern overview toggle"),
    terminal = hl.dsp.exec_cmd("kitty"),
    browser = hl.dsp.exec_cmd("vivaldi"),
    fileManager = hl.dsp.exec_cmd("dolphin"),
    closeWindow = hl.dsp.window.close(),
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
    moveToWorkspace1 = hl.dsp.window.move({ workspace = 1 }),
    moveToWorkspace2 = hl.dsp.window.move({ workspace = 2 }),
    moveToWorkspace3 = hl.dsp.window.move({ workspace = 3 }),
    moveToWorkspace4 = hl.dsp.window.move({ workspace = 4 }),
    moveToWorkspace5 = hl.dsp.window.move({ workspace = 5 }),
    moveToWorkspace6 = hl.dsp.window.move({ workspace = 6 }),
    moveToWorkspace7 = hl.dsp.window.move({ workspace = 7 }),
    moveToWorkspace8 = hl.dsp.window.move({ workspace = 8 }),
    moveToWorkspace9 = hl.dsp.window.move({ workspace = 9 }),
    moveToWorkspace10 = hl.dsp.window.move({ workspace = 10 }),
    screenshotRegion = hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"),
    screenshotWindow = hl.dsp.exec_cmd("grim -g \"$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\" - | wl-copy"),
    screenshotFull = hl.dsp.exec_cmd("grim - | wl-copy"),
    gameMode = hl.dsp.exec_cmd("modern game mode toggle"),
    colorPicker = hl.dsp.exec_cmd("hyprpicker -a"),
    clipboardHistory = hl.dsp.exec_cmd("modern clipboard show"),
}

for action, dispatcher in pairs(bindings) do
    local key = combo(action)
    if key then
        hl.bind(key, dispatcher)
    end
end

-- Media/backlight keys are hardware-fixed X11 keysyms, not user-remapped
-- via the shortcut editor, so they're bound directly rather than through
-- config.json — matching the ArchWiki's documented pattern.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("modern volume up"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("modern volume down"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("modern volume mute-toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("modern volume mic-mute-toggle"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("modern media play-pause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("modern media play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("modern media next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("modern media previous"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +5%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"))
