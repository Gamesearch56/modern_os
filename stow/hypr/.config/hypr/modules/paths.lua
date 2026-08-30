-- Repo and script locations. Hyprland Lua must not concatenate
-- `$HOME/modern_dotfile/scripts` in every module.

local home = os.getenv("HOME") or ""

return {
    home = home,
    repo = home .. "/modern_dotfile",
    scripts = home .. "/modern_dotfile/scripts",
    modern = home .. "/modern_dotfile/scripts/modern",
    modern_launch = home .. "/modern_dotfile/scripts/modern-launch",
}
