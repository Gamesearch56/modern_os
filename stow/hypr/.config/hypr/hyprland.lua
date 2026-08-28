-- modern_dotfile — Hyprland entry point.
--
-- Every module below reads its behaviour from config.json via
-- modules/config.lua (see docs/ARCHITECTURE.md's "two data flows"). This
-- file itself should never grow — it only requires modules, in load
-- order. Colors come from modules/colors.lua, which
-- scripts/theme-apply.sh regenerates on every theme change; never hand-edit it.
--
-- require() (not dofile()) so each module gets its own Lua scope and
-- ConfigWatcher dependency tracking — see docs/DECISIONS.md and
-- AGENTS.md's Hyprland Lua rule.

require("modules.env")
require("modules.general")
require("modules.colors")
require("modules.animations")
require("modules.input")
require("modules.monitors")
require("modules.workspaces")
require("modules.windowrules")
require("modules.keybinds")
require("modules.autostart")
