-- Greetd kiosk. Copied by install/lib/greetd.sh.
-- GREETD_SOCK must reach qs: Quickshell only connects when it is set.
local function greetd_sock()
    local s = os.getenv("GREETD_SOCK")
    if s and s ~= "" then
        return s
    end
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    if not runtime then
        return ""
    end
    local ok, f = pcall(io.open, runtime .. "/greetd.sockpath", "r")
    if not ok or not f then
        return ""
    end
    s = (f:read("*l") or ""):gsub("%s+$", "")
    f:close()
    return s
end

local sock = greetd_sock()
if sock ~= "" then
    hl.env("GREETD_SOCK", sock)
end
hl.env("QT_QPA_PLATFORM", "wayland")
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb" })
hl.on("hyprland.start", function()
    if sock ~= "" then
        hl.exec_cmd("env GREETD_SOCK='" .. sock:gsub("'", "'\\''") .. "' qs -c greeter")
    else
        hl.exec_cmd("qs -c greeter")
    end
    -- Seat focus follows the pointer; (0,0) is the leftmost output.
    hl.exec_cmd("hyprctl dispatch movecursor 64 64")
end)
