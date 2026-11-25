-- Greetd kiosk. Copied by install/lib/greetd.sh.
-- GREETD_SOCK must reach qs: Quickshell only connects when it is set.
-- Monitor HDR/cm follows the desktop snapshot (description keys, never
-- a connector name). Catch-all stays srgb when no profile matches.

package.path = "/etc/greetd/?.lua;" .. (package.path or "")

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

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local passthrough = {
    "vrr",
    "bitdepth",
    "sdrbrightness",
    "sdrsaturation",
    "sdr_eotf",
    "sdr_min_luminance",
    "sdr_max_luminance",
    "min_luminance",
    "max_luminance",
    "max_avg_luminance",
    "supports_hdr",
    "supports_wide_color",
    "icc",
}

local function apply_monitor_profiles(profiles)
    if type(profiles) ~= "table" then
        return
    end
    for description, p in pairs(profiles) do
        if type(description) == "string" and type(p) == "table" then
            local spec = {
                output = "desc:" .. description,
                mode = p.mode or "preferred",
                position = p.position or "auto",
                scale = p.scale or 1,
            }
            for _, key in ipairs(passthrough) do
                if p[key] ~= nil then
                    spec[key] = p[key]
                end
            end
            if p.hdr then
                spec.cm = "hdr"
                if spec.bitdepth == nil then
                    spec.bitdepth = 10
                end
            else
                local cm = p.cm
                if cm == "hdr" or cm == "hdredid" then
                    cm = "srgb"
                end
                spec.cm = cm or "srgb"
            end
            hl.monitor(spec)
        end
    end
end

local sock = greetd_sock()
if sock ~= "" then
    hl.env("GREETD_SOCK", sock)
end
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("PATH", "/usr/bin:/bin:" .. (os.getenv("PATH") or "/usr/bin"))

local function sanitize_kb(s)
    return tostring(s or ""):gsub("[^%w,_%-]", "")
end

local function hex_bg(value)
    if type(value) ~= "string" then
        return "0x141218"
    end
    local h = value:gsub("^#", "")
    if #h == 6 then
        return "0x" .. h
    end
    return "0x141218"
end

local json_ok, json = pcall(require, "json")
local tokens = {}
if json_ok and json and json.decode then
    local raw = read_file("/var/lib/modern/session/tokens.json")
    local data = raw and json.decode(raw) or {}
    tokens = data.color or {}
end

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_hyprland_guiutils_check = true,
        background_color = hex_bg(tokens.surface),
    },
    -- Same screen the session disables. The greeter starts first after
    -- a reboot, so an updated Hyprland would otherwise cover the login.
    ecosystem = {
        no_update_news = true,
    },
    render = {
        cm_auto_hdr = 0,
    },
})

if json_ok and json and json.decode then
    local raw = read_file("/var/lib/modern/session/monitors.json")
    local data = raw and json.decode(raw) or {}
    apply_monitor_profiles(data.profiles or data)
    raw = read_file("/var/lib/modern/session/keyboard.json")
    data = raw and json.decode(raw) or {}
    local layout = sanitize_kb(data.layout)
    if layout == "" then
        layout = "us"
    end
    hl.config({
        input = {
            kb_layout = layout,
            kb_variant = sanitize_kb(data.variant),
        },
    })
end

local function sh_quote(s)
    return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- The greeter's home is private, so its shell log goes to the shared
-- session dir (group modern, 0640) where a bug report can read it. If
-- that dir is not writable the login screen still starts, unlogged.
local greeter_run = [[
umask 027
log=/var/lib/modern/session/greeter.log
if [ -w "${log%/*}" ] && { [ ! -e "$log" ] || [ -w "$log" ]; }; then
    if [ "$(wc -c 2>/dev/null <"$log" || echo 0)" -gt 1048576 ]; then mv -f "$log" "$log.1"; fi
    printf '\n== login screen %s\n' "$(date -Is)" >>"$log"
    exec qs -c greeter >>"$log" 2>&1
fi
exec qs -c greeter]]

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb" })
hl.on("hyprland.start", function()
    -- Wallpaper is the greeter Image. An extra wallpaper daemon here
    -- outlives qs and blocks greetd from starting the user session.
    local env = sock ~= "" and ("env GREETD_SOCK=" .. sh_quote(sock) .. " ") or ""
    hl.exec_cmd(env .. "sh -c " .. sh_quote(greeter_run))
    -- A warp before the layer maps does not send pointer-enter. The
    -- greeter holds HyprlandFocusGrab; this retry is only a fallback.
    if hl.timer and hl.dsp and hl.dsp.cursor and hl.dsp.cursor.move then
        hl.timer(function()
            pcall(hl.dispatch, hl.dsp.cursor.move({ x = 96, y = 96 }))
        end, { timeout = 400, type = "oneshot" })
    end
end)
