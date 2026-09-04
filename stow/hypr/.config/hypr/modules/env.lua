-- Toolkit / icon-theme env must be set before the display server
-- finishes init (wiki.hypr.land Environment-variables). Child processes
-- (qs, Nautilus, portals) inherit these; without them Qt falls back to
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
local paths = require("modules.paths")
local path = os.getenv("PATH") or "/usr/bin"
hl.env("MODERN_REPO", paths.repo)
hl.env("PATH", paths.scripts .. ":" .. paths.home .. "/.local/bin:" .. path)

-- NVIDIA wiki env only when install.sh wrote gpu=nvidia. AMD/Intel stay unset.
do
    local hw_path = (os.getenv("XDG_STATE_HOME") or (paths.home .. "/.local/state"))
        .. "/modern/hw.json"
    local f = io.open(hw_path, "r")
    if f then
        local raw = f:read("*a") or ""
        f:close()
        if raw:find('"gpu"%s*:%s*"nvidia"', 1, false) then
            hl.env("LIBVA_DRIVER_NAME", "nvidia")
            hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
            hl.env("NVD_BACKEND", "direct")
        end
    end
end
