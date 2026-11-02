-- Vivaldi --app windows on the main profile. A private profile is
-- another browser, so a clicked link opens that profile instead of a
-- tab in the browser that is already open. The window class still
-- carries the site, so session_apps can park the window.
local paths = require("modules.paths")

local function app_cmd(url)
    return paths.scripts .. "/vivaldi --app=" .. url
end

return {
    ["proton-mail"] = app_cmd("https://mail.proton.me"),
    ["proton-calendar"] = app_cmd("https://calendar.proton.me"),
    ["whatsapp"] = app_cmd("https://web.whatsapp.com"),
}
