-- modern_dotfile — Hyprland entry point.
--
-- Every module below reads its behaviour from config.json via
-- modules/config.lua (see docs/ARCHITECTURE.md's "two data flows"). This
-- file itself should never grow — it only requires modules, in load
-- order. Colors come from modules/theme_colors.lua, which loads
-- generated modules/colors.lua or tokens.json so a missing gitignored
-- file cannot drop the compositor into emergency mode.
--
-- require() (not dofile()) so each module gets its own Lua scope and
-- ConfigWatcher dependency tracking — see docs/DECISIONS.md and
-- AGENTS.md's Hyprland Lua rule.
-- Stow uses a symlink; ConfigWatcher stats that, not the target, so a
-- repo edit of paths.lua can stay cached from session start (binds then
-- still exec $HOME/modern_dotfile/scripts/…). Drop the cache so reload
-- re-resolves the clone.

do
    local drop = {}
    for k in pairs(package.loaded) do
        if type(k) == "string" and (k:sub(1, 8) == "modules." or k:sub(1, 4) == "lib.") then
            drop[#drop + 1] = k
        end
    end
    for i = 1, #drop do
        package.loaded[drop[i]] = nil
    end
end

require("modules.permissions")
require("modules.env")
require("modules.general")
require("modules.theme_colors")
require("modules.animations")
require("modules.input")
require("modules.monitors")
require("modules.workspaces")
require("modules.windowrules")
require("modules.browser_popups")
require("modules.games")
require("modules.keybinds")
require("modules.mouse_windows")
require("modules.power")
require("modules.session_apps")
require("modules.autostart")

-- After window rules. A reload reapplies special:background onto the
-- open web apps and shows that workspace; this closes it again.
require("modules.workspaces").pin_background()
