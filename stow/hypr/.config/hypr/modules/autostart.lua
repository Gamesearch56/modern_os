-- hl.on("hyprland.start", ...) fires exactly once per session, even
-- though hyprland.lua re-parses on every save — this is what the old
-- setup's autostart.lua got wrong by pointing at a nonexistent script
-- path (docs/DECISIONS.md's audit note). Never put an autostart command
-- directly at file scope; always inside this callback.

local config = require("modules.config")

hl.on("hyprland.start", function()
    -- Import compositor env into systemd --user so units (the shell)
    -- can open the Wayland display. start-hyprland / UWSM do this
    -- already; a raw `Hyprland` TTY start does not.
    hl.exec_cmd("sh -lc '"
        .. "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE; "
        .. "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP; "
        .. "systemctl --user start hyprpolkitagent; "
        .. "systemctl --user start modern-shell.service "
        .. "|| exec quickshell -p \"$HOME/.config/quickshell/modern\"'")

    hl.exec_cmd("hypridle")

    -- Clipboard history backend (see Modules/Cheatsheet + the
    -- "clipboardHistory" bind in modules/keybinds.lua).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Wallpaper daemon, then restore the last (or shipped default) image.
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper\"; default=\"$HOME/.config/modern/wallpapers/default.jpg\"; if [ -f \"$state\" ]; then img=$(cat \"$state\"); elif [ -f \"$default\" ]; then img=\"$default\"; else exit 0; fi; [ -f \"$img\" ] && awww img \"$img\"'")

    if config.value("kdeconnect.enabled", true) then
        hl.exec_cmd("systemctl --user start kdeconnect.service")
    end
end)
