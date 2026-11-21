-- Live ISO kiosk only. Installed sessions use ~/.config/hypr/hyprland.lua.
-- Autostart must be inside hyprland.start — file-scope exec is ignored
-- on reload and never opens Calamares. Keep liveuser + start-hyprland +
-- exec calamares together: other combinations drew no frame.

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb" })

hl.window_rule({
    name = "calamares-kiosk",
    match = { class = "calamares" },
    float = true,
    center = true,
    size = { "90%", "90%" },
})
hl.window_rule({
    name = "calamares-kiosk-title",
    match = { title = "[Cc]alamares" },
    float = true,
    center = true,
    size = { "90%", "90%" },
})
hl.window_rule({
    name = "live-browser",
    match = { class = ".*[Ff]irefox.*" },
    float = true,
    center = true,
    size = { "85%", "85%" },
})

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("calamares"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("calamares"))

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sh -lc 'sleep 0.4; awww img /usr/share/modern/wallpaper.jpg || true'")
    hl.exec_cmd("sh -lc 'sleep 0.6; command -v calamares >/dev/null && exec calamares'")
end)
