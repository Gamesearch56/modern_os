-- Hyprland ≥ 0.55 asks before a process may load a .so plugin. Allow
-- hyprpm only (wiki.hypr.land Plugins/Using-Plugins). hyprctl plugin
-- load stays at the default so a random .so cannot be injected that way.
-- These rules register at compositor start, not on hyprctl reload.

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
