-- Toolkit / icon-theme env must be set before the display server
-- finishes init (wiki.hypr.land Environment-variables). Child processes
-- (qs, Dolphin, portals) inherit these; without them Qt falls back to
-- a light Fusion palette and Quickshell cannot resolve Papirus icons.

local config = require("modules.config")

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QS_ICON_THEME", config.value("design.iconTheme", "Papirus-Dark"))
hl.env("XCURSOR_THEME", config.value("design.cursorTheme", "Bibata-Modern-Classic"))
hl.env("XCURSOR_SIZE", tostring(config.value("design.cursorSize", 24)))
hl.env("HYPRCURSOR_THEME", config.value("design.cursorTheme", "Bibata-Modern-Classic"))
hl.env("HYPRCURSOR_SIZE", tostring(config.value("design.cursorSize", 24)))

-- Hyprland exec and qs inherit this, not ~/.bashrc. Keep repo scripts
-- (modern, theme-apply.sh, screenshot.sh) resolvable without a login shell.
local home = os.getenv("HOME") or ""
local path = os.getenv("PATH") or "/usr/bin"
hl.env("PATH", home .. "/modern_dotfile/scripts:" .. home .. "/.local/bin:" .. path)
