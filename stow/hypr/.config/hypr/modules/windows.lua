-- Overlay / chrome window titles for windowrules.lua so a new
-- FloatingWindow is listed once.

return {
    { name = "modern-settings", title = "modern.settings", size = { 1040, 720 }, opaque = false },
    -- A normal window: other apps and a second file manager stay clickable.
    { name = "modern-files", title = "modern.files", size = { 1180, 720 }, opaque = false, dim = false },
    { name = "modern-store", title = "modern.store", size = { 1040, 720 }, opaque = false },
    { name = "modern-bugreport", title = "modern.bugreport", size = { 784, 788 }, opaque = false },
    { name = "modern-wallpaper", title = "modern.wallpaper", size = { 1040, 720 }, opaque = false },
    { name = "modern-cheatsheet", title = "modern.cheatsheet", size = { 1040, 720 }, opaque = false },
    { name = "modern-wallpaper-provider", title = "modern.wallpaper-provider", size = { 1200, 800 }, opaque = false },
}
