-- hl.on("hyprland.start", ...) fires exactly once per session, even
-- though hyprland.lua re-parses on every save. A command at file scope
-- would re-exec on each save. Always put autostart inside this callback.

local config = require("modules.config")
local paths = require("modules.paths")

hl.on("hyprland.start", function()
    -- Shell first so the first frame is the bar, not a bus timeout.
    -- Wallpaper and systemd stay in the background.
    hl.exec_cmd("sh -lc '"
        .. "mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/modern\"; "
        .. "log=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/quickshell.log\"; "
        .. "export QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct "
        .. "QS_ICON_THEME=\"${QS_ICON_THEME:-Papirus-Dark}\"; "
        .. "exec qs -c modern >>\"$log\" 2>&1'")

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sh -lc 'img=/var/lib/modern/session/wallpaper.jpg; state=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper\"; default=\"$HOME/.config/modern/wallpapers/default.jpg\"; if [ -f \"$img\" ]; then :; elif [ -f \"$state\" ]; then img=$(cat \"$state\"); elif [ -f \"$default\" ]; then img=\"$default\"; else exit 0; fi; [ -f \"$img\" ] && awww img \"$img\" --transition-type none'")

    -- Background: sequential timeout 2 calls must not contend with qs.
    hl.exec_cmd("sh -lc '("
        .. "if systemctl --user is-active --quiet modern-shell.service; then "
        .. "timeout 1 systemctl --user stop modern-shell.service || true; fi; "
        .. "timeout 2 systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_ID XDG_SESSION_TYPE QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION QS_ICON_THEME || true; "
        .. "timeout 2 dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION || true; "
        .. "timeout 2 systemctl --user stop hyprpolkitagent.service || true; "
        .. "timeout 2 systemctl --user daemon-reload || true; "
        .. "timeout 2 systemctl --user reset-failed phylax.service || true; "
        .. "timeout 2 systemctl --user start phylax || true) &'")

    hl.exec_cmd("sh -lc '" .. paths.scripts .. "/hypridle-apply.sh'")
    -- hyprpm stores plugins in /var/cache/hyprpm/$USER and needs pkexec
    -- to create that tree the first time. Calling reload before the
    -- store exists dies with "Failed to run a superuser cmd" and the
    -- -n flag turns that into the startup "plugin loaded failed"
    -- overlay. Skip until the user has run `hyprpm add` once.
    hl.exec_cmd("sh -lc 'if [ -d /var/cache/hyprpm/\"$USER\" ]; then hyprpm reload -n; fi'")

    if config.value("kdeconnect.enabled", true) then
        -- Package unit is kdeconnectd via XDG autostart; kdeconnect.service
        -- is not shipped. Start the daemon if it is not already running.
        hl.exec_cmd("sh -lc 'pgrep -u \"$USER\" -x kdeconnectd >/dev/null || kdeconnectd &'")
    end

    -- GameMode raises the CPU governor only while a game is registered,
    -- then restores it — other apps stay on the default policy.
    hl.exec_cmd("sh -lc 'command -v gamemoded >/dev/null 2>&1 || exit 0; pgrep -u \"$USER\" -x gamemoded >/dev/null || gamemoded -d'")

    require("modules.session_apps").on_start()
end)
