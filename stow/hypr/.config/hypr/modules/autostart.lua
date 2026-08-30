-- hl.on("hyprland.start", ...) fires exactly once per session, even
-- though hyprland.lua re-parses on every save — this is what the old
-- setup's autostart.lua got wrong by pointing at a nonexistent script
-- path (docs/DECISIONS.md's audit note). Never put an autostart command
-- directly at file scope; always inside this callback.

local config = require("modules.config")

hl.on("hyprland.start", function()
    -- Import compositor env, then start the shell as a child of this
    -- compositor. systemd --user is one instance per login, so a leftover
    -- Hyprland on another TTY would keep modern-shell.service pointed at
    -- the old WAYLAND_DISPLAY and this session would get wallpaper only.
    hl.exec_cmd("sh -lc '"
        .. "mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/modern\"; "
        .. "log=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/quickshell.log\"; "
        .. "export QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=qt6ct "
        .. "QS_ICON_THEME=\"${QS_ICON_THEME:-Papirus-Dark}\"; "
        .. "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION QS_ICON_THEME; "
        .. "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_WAYLAND_DISABLE_WINDOWDECORATION; "
        .. "gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true; "
        .. "systemctl --user start hyprpolkitagent || true; "
        .. "systemctl --user stop modern-shell.service 2>/dev/null || true; "
        .. "exec qs -c modern >>\"$log\" 2>&1'")

    hl.exec_cmd("hypridle")
    -- hyprpm stores plugins in /var/cache/hyprpm/$USER and needs pkexec
    -- to create that tree the first time. Calling reload before the
    -- store exists dies with "Failed to run a superuser cmd" and the
    -- -n flag turns that into the startup "plugin loaded failed"
    -- overlay. Skip until the user has run `hyprpm add` once. hyprbars
    -- itself reloads config from PLUGIN_INIT, so titlebar.lua applies
    -- on the second parse once the .so is in.
    hl.exec_cmd("sh -lc 'if [ -d /var/cache/hyprpm/\"$USER\" ]; then hyprpm reload -n; fi'")

    -- Clipboard history backend (see Modules/Cheatsheet + the
    -- "clipboardHistory" bind in modules/keybinds.lua).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Wallpaper daemon, then restore the last (or shipped default) image.
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sh -lc 'state=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/current-wallpaper\"; default=\"$HOME/.config/modern/wallpapers/default.jpg\"; if [ -f \"$state\" ]; then img=$(cat \"$state\"); elif [ -f \"$default\" ]; then img=\"$default\"; else exit 0; fi; [ -f \"$img\" ] && awww img \"$img\"'")

    if config.value("kdeconnect.enabled", true) then
        -- Package unit is kdeconnectd via XDG autostart; kdeconnect.service
        -- is not shipped. Start the daemon if it is not already running.
        hl.exec_cmd("sh -lc 'pgrep -u \"$USER\" -x kdeconnectd >/dev/null || kdeconnectd &'")
    end

    local autostart = config.value("general.autostart", {})
    local modern_launch = (os.getenv("HOME") or "") .. "/modern_dotfile/scripts/modern-launch"

    local function stem(id)
        return tostring(id or ""):gsub("%.desktop$", "")
    end

    local function is_background(name)
        if name == "" then
            return false
        end
        for _, role in ipairs({ "calendar", "mail", "communication" }) do
            if stem(config.value("apps.defaults." .. role, "")) == name then
                return true
            end
        end
        return false
    end

    if type(autostart) == "table" then
        for _, id in ipairs(autostart) do
            local name = stem(id)
            if name ~= "" then
                if is_background(name) then
                    hl.exec_cmd(modern_launch .. " --background " .. name)
                else
                    hl.exec_cmd(modern_launch .. " " .. name)
                end
            end
        end
    end
end)
