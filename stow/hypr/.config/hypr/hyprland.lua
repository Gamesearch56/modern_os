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

require("modules.permissions")
require("modules.env")
require("modules.general")
require("modules.theme_colors")
require("modules.animations")
require("modules.input")
require("modules.monitors")
require("modules.workspaces")
require("modules.windowrules")
require("modules.games")
require("modules.titlebar")
require("modules.keybinds")
require("modules.power")
require("modules.autostart")
