-- hl.on("hyprland.start", ...) fires exactly once per session, even
-- though hyprland.lua re-parses on every save — this is what the old
-- setup's autostart.lua got wrong by pointing at a nonexistent script
-- path (docs/DECISIONS.md's audit note). Never put an autostart command
-- directly at file scope; always inside this callback.

local config = require("modules.config")

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")

    -- Clipboard history backend (see Modules/Cheatsheet + the
    -- "clipboardHistory" bind in modules/keybinds.lua).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Wallpaper daemon. Verify awww's exact invocation once installed —
    -- see docs/TROUBLESHOOTING.md; some wallpaper daemons need an
    -- explicit `init`/`daemon` subcommand before accepting `awww img`.
    hl.exec_cmd("awww-daemon")

    -- The shell itself, run as a systemd --user unit (see
    -- docs/DECISIONS.md and the shell-watchdog service) so a Quickshell
    -- crash doesn't need a Hyprland reload to recover from.
    hl.exec_cmd("systemctl --user start modern-shell.service")

    if config.value("kdeconnect.enabled", true) then
        hl.exec_cmd("systemctl --user start kdeconnect.service")
    end
end)
