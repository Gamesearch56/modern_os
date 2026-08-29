-- hl.on("hyprland.start", ...) fires exactly once per session, even
-- though hyprland.lua re-parses on every save — this is what the old
-- setup's autostart.lua got wrong by pointing at a nonexistent script
-- path (docs/DECISIONS.md's audit note). Never put an autostart command
-- directly at file scope; always inside this callback.

local config = require("modules.config")

hl.on("hyprland.start", function()
    -- exec qs so Hyprland tracks the Quickshell process, not a wrapper
    -- shell. A while-loop left sh as the child; that never stayed up
    -- (no qs in the destuser session). Same start as the working TTY.
    hl.exec_cmd("sh -lc '"
        .. "mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/modern\"; "
        .. "log=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/quickshell.log\"; "
        .. "exec qs -c modern >>\"$log\" 2>&1'")

    -- Best-effort; timeout so a missing bus cannot stall the session.
    hl.exec_cmd("sh -lc '"
        .. "timeout 2 systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE || true; "
        .. "timeout 2 dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP || true; "
        .. "timeout 2 systemctl --user stop modern-shell.service || true; "
        .. "timeout 2 systemctl --user start hyprpolkitagent || true'")

    hl.exec_cmd("hypridle")

    -- Clipboard history backend (see Modules/Cheatsheet + the
    -- "clipboardHistory" bind in modules/keybinds.lua).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Wallpaper daemon, then restore the last (or shipped default) image.
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper\"; default=\"$HOME/.config/modern/wallpapers/default.jpg\"; if [ -f \"$state\" ]; then img=$(cat \"$state\"); elif [ -f \"$default\" ]; then img=\"$default\"; else exit 0; fi; [ -f \"$img\" ] && awww img \"$img\"'")

    if config.value("kdeconnect.enabled", true) then
        hl.exec_cmd("sh -lc 'timeout 2 systemctl --user start kdeconnect.service || true'")
    end
end)
