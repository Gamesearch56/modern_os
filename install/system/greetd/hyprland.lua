-- Gated greetd kiosk. Copied by provision-iso.sh, not install.sh.
hl.env("QT_QPA_PLATFORM", "wayland")
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb" })
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c greeter")
end)
