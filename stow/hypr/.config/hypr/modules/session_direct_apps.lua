-- Per-app Vivaldi --app= commands (own user-data-dir so exec_cmd rules apply).
-- scripts/vivaldi adds --in-process-gpu only while gaming.browserLight is on.
local paths = require("modules.paths")
local home_cfg = (os.getenv("XDG_CONFIG_HOME") and os.getenv("XDG_CONFIG_HOME") ~= "")
    and os.getenv("XDG_CONFIG_HOME")
    or ((os.getenv("HOME") or "") .. "/.config")

local function app_cmd(name, url)
    return paths.scripts .. "/vivaldi --user-data-dir=" .. home_cfg .. "/vivaldi-apps/" .. name
        .. " --app=" .. url
end

return {
    ["proton-mail"] = app_cmd("proton-mail", "https://mail.proton.me"),
    ["proton-calendar"] = app_cmd("proton-calendar", "https://calendar.proton.me"),
    ["whatsapp"] = app_cmd("whatsapp", "https://web.whatsapp.com"),
}
