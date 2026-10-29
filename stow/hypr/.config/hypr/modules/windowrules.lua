-- Window rules, driven entirely by config.json's windowRules array —
-- Settings > Windows' rule table (match on class/title, then
-- float/size/position/workspace/opacity/...), replacing hand-edited Lua
-- (docs/ARCHITECTURE.md's "two data flows" — Settings never writes Lua).
--
-- Effect names must match 0.56's WINDOW_RULE_EFFECT_DESCS exactly:
-- dim_around (not dimaround), size as {w, h}, opacity as a string.
-- Leftover plugin effects (hyprbars:no_bar, …) are unknown without
-- that plugin and must not be applied.

local config = require("modules.config")
local glass = require("modules.glass")
local overlays = require("modules.windows")

local function hyprbars_loaded()
    return hl.plugin and hl.plugin.hyprbars ~= nil
end

local function vec2(v)
    if type(v) ~= "string" then
        return v
    end
    local a, b = v:match("^(%S+)%s+(%S+)$")
    if not a then
        return v
    end
    return { tonumber(a) or a, tonumber(b) or b }
end

local function normalize(rule)
    local out = {}
    for k, v in pairs(rule) do
        local key = k
        if key == "dimaround" then
            key = "dim_around"
        end
        local plugin_effect = type(key) == "string" and key:sub(1, 9) == "hyprbars:"
        if not plugin_effect or hyprbars_loaded() then
            if key == "size" or key == "move" or key == "max_size" or key == "min_size" then
                out[key] = vec2(v)
            elseif key == "opacity" and type(v) == "number" then
                out[key] = tostring(v) .. " override"
            else
                out[key] = v
            end
        end
    end
    return out
end

local function apply(rule)
    if not rule or not rule.match then
        return
    end
    hl.window_rule(normalize(rule))
end

for _, rule in ipairs(config.value("windowRules", {})) do
    -- Replaced by modules/games.lua; leftover special:game hid titles.
    if rule.name ~= "steam-game" then
        apply(rule)
    end
end

-- One default, kept even with an empty user rule list: JetBrains IDEs
-- have well-documented Wayland/XWayland focus-stealing issues (see
-- docs/DECISIONS.md's audit and the ArchWiki Hyprland troubleshooting
-- section) — this is cheap insurance, not a personal preference.
apply({
    name = "xwayland-no-initial-focus",
    match = { xwayland = true },
    no_initial_focus = true,
})

-- Chromium/Vivaldi (and other Electron shells): after HTML5 video
-- fullscreen, the client echoes set_maximized because Hyprland advertised
-- MAXIMIZED at map time to hide CSD. Honoring that enters fullscreen
-- mode 1 and covers every other tile on the workspace — often noticed
-- only when clicking elsewhere or switching workspaces (hyprwm/Hyprland
-- #13322). Super+F still uses the exclusive-fullscreen dispatcher;
-- games.lua forces state 2 the same way. Client maximize is unused.
apply({
    name = "suppress-client-maximize",
    suppress_event = "maximize",
})

-- imv fills its tile. On a virtual GPU the acrylic pass replaces that
-- tile with black, so the picture never shows. A real GPU is unchanged
-- because the viewer background is already opaque.
apply({
    name = "imv-no-blur",
    match = { class = "imv" },
    no_blur = true,
})

-- Phylax (GTK4 polkit agent) app_id. Glass like Settings chrome:
-- float+center, dim_around as scrim, design.transparency.
-- pin keeps the prompt above modern.store / modern.settings.
-- focus_on_activate honours GTK present(); stay_focused holds the seat
-- after that. follow_mouse=1 otherwise leaves keys on Settings.
apply({
    name = "polkit-auth-dialog",
    match = { class = "io.github.jakebgrant.phylax" },
    float = true,
    center = true,
    pin = true,
    dim_around = true,
    stay_focused = true,
    focus_on_activate = true,
    border_size = 1,
    opacity = glass.wash(),
})

local function phylax_focus(w)
    if type(w) ~= "table" then
        return
    end
    local class = tostring(w.class or w.initial_class or "")
    if not class:find("phylax", 1, true) then
        return
    end
    if w.mapped == false then
        return
    end
    if not (hl.dispatch and hl.dsp and hl.dsp.focus) then
        return
    end
    local function go()
        pcall(function()
            hl.dispatch(hl.dsp.focus({ window = w }))
        end)
    end
    go()
    if hl.timer then
        pcall(hl.timer, go, { timeout = 80, type = "oneshot" })
    end
end

if hl.on then
    hl.on("window.open_early", phylax_focus)
    hl.on("window.open", phylax_focus)
    hl.on("window.urgent", phylax_focus)
end

-- Nautilus is a tiled app window, not a HUD. Punching wallpaper
-- through the icon view (design.transparency) washed out labels and
-- toolbar icons. Opaque surface; wallpaper stays in the compositor gaps.
apply({
    name = "nautilus-opaque",
    match = { class = "org.gnome.Nautilus|org.gnome.nautilus|nautilus" },
    opaque = true,
})

-- Spacebar Quick Look video leftover class (mpv). Image/text use a Quickshell overlay.
apply({
    name = "modern-quicklook",
    match = { class = "modern.quicklook" },
    float = true,
    center = true,
    dim_around = true,
})

-- GNOME Sushi (Nautilus Space). Toplevel on Hyprland unless floated;
-- dim_around is the overlay scrim. No stay_focused: Nautilus selection
-- changes must reach the view so the preview auto-replaces.
apply({
    name = "nautilus-previewer",
    match = { class = "org.gnome.NautilusPreviewer|sushi" },
    float = true,
    center = true,
    dim_around = true,
    opaque = true,
    border_size = 1,
})

for _, w in ipairs(overlays) do
    local rule = {
        name = w.name,
        match = { title = w.title },
        float = true,
        center = true,
        dim_around = true,
        opaque = w.opaque == true,
    }
    if w.size then
        rule.size = w.size
    end
    if w.max_size then
        rule.max_size = w.max_size
    end
    apply(rule)
end
