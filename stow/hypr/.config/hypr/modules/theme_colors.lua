-- Border colors. Prefer the matugen file (gitignored
-- `modules/colors.lua`) but never require it: a missing module aborts
-- hyprland.lua and leaves the emergency overlay. tokens.json is the
-- same palette. Surface fills the
-- compositor so the greetd handoff is not a black frame.

local json = require("lib.json")
local glass = require("modules.glass")

local function hex_stripped(value)
    if type(value) ~= "string" then
        return nil
    end
    return (value:gsub("^#", ""))
end

local function apply_surface(surface)
    if type(surface) ~= "string" or #surface ~= 6 then
        return
    end
    hl.config({
        misc = {
            background_color = "0x" .. surface,
        },
        -- A whisper of the surface role, not the acrylic default blue.
        -- Alpha follows glass.lua so light surfaces do not milk the frost.
        decoration = {
            blur = {
                acrylic = { tint = glass.acrylic_tint(surface) },
            },
        },
    })
end

-- MD3 shadow role at elevation opacities (level 2 active / level 1
-- inactive). Hyprland's unset color_inactive is opaque white.
local function apply_shadow(shadow)
    if type(shadow) ~= "string" or #shadow ~= 6 then
        shadow = "000000"
    end
    hl.config({
        decoration = {
            shadow = {
                color = "rgba(" .. shadow .. "1a)",
                color_inactive = "rgba(" .. shadow .. "14)",
            },
        },
    })
end

local home = os.getenv("HOME") or ""
local tokens = nil
local f = io.open(home .. "/.config/modern/tokens.json", "r")
if f then
    local raw = f:read("*a")
    f:close()
    local ok_tok, data = pcall(json.decode, raw)
    if ok_tok and type(data) == "table" and type(data.color) == "table" then
        tokens = data.color
    end
end

local surface = tokens and hex_stripped(tokens.surface) or nil
local shadow = tokens and hex_stripped(tokens.shadow) or nil

local ok, generated = pcall(require, "modules.colors")
if ok then
    apply_surface(surface)
    apply_shadow(shadow)
    return generated
end

if not tokens then
    return {}
end

local primary = hex_stripped(tokens.primary)
local outline = hex_stripped(tokens.outlineVariant)
if primary and outline then
    hl.config({
        general = {
            ["col.active_border"] = "rgba(" .. primary .. "ff)",
            ["col.inactive_border"] = "rgba(" .. outline .. "ff)",
        },
    })
end
apply_surface(surface)
apply_shadow(shadow)
return {}
