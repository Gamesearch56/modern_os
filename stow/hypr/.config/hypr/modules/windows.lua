-- Overlay / chrome window titles for windowrules.lua so a new
-- FloatingWindow is listed once.

return {
    { name = "modern-settings", title = "modern.settings", size = { 1040, 720 }, opaque = false },
    -- The title follows the open file, so the editor matches on its app id.
    -- Width/height match Tokens.window.editorWidth / editorHeight. Listed
    -- before Files: the editor's file chooser shares the app id and must
    -- take the Files size, and the later rule wins.
    { name = "modern-editor", class = "modern.editor", size = { 832, 640 }, opaque = false, dim = false },
    -- A normal window: other apps and a second file manager stay clickable.
    -- Width/height match Tokens.window.filesWidth / filesHeight.
    { name = "modern-files", title = "modern.files", size = { 1172, 704 }, opaque = false, dim = false },
    { name = "modern-store", title = "modern.store", size = { 1040, 720 }, opaque = false },
    { name = "modern-bugreport", title = "modern.bugreport", size = { 784, 788 }, opaque = false },
    { name = "modern-wallpaper", title = "modern.wallpaper", size = { 1040, 720 }, opaque = false },
    { name = "modern-cheatsheet", title = "modern.cheatsheet", size = { 1040, 720 }, opaque = false },
    { name = "modern-wallpaper-provider", title = "modern.wallpaper-provider", size = { 1200, 800 }, opaque = false },
}
