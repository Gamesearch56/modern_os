-- Border and hyprbars surface colors. Prefer the matugen file
-- (gitignored `modules/colors.lua`); checking out a commit that
-- `git rm`'d that tracked file used to abort hyprland.lua and leave
-- the emergency overlay. tokens.json is the same palette.

local json = require("lib.json")

local function hex_stripped(value)
    if type(value) ~= "string" then
        return nil
    end
    return (value:gsub("^#", ""))
end

local function apply(primary, outline, surface, on_surface)
    if not primary or not outline then
        return { hyprbars = {} }
    end
    hl.config({
        general = {
            ["col.active_border"] = "rgba(" .. primary .. "ff)",
            ["col.inactive_border"] = "rgba(" .. outline .. "ff)",
        },
    })
    local hyprbars = {}
    if surface then
        hyprbars.bar_color = "rgba(" .. surface .. "d9)"
    end
    if on_surface then
        hyprbars["col.text"] = "rgb(" .. on_surface .. ")"
    end
    return { hyprbars = hyprbars }
end

local ok, generated = pcall(require, "modules.colors")
if ok then
    return generated
end

local home = os.getenv("HOME") or ""
local f = io.open(home .. "/.config/modern/tokens.json", "r")
if not f then
    return { hyprbars = {} }
end
local raw = f:read("*a")
f:close()

ok, generated = pcall(json.decode, raw)
if not ok or type(generated) ~= "table" or type(generated.color) ~= "table" then
    return { hyprbars = {} }
end

local c = generated.color
return apply(
    hex_stripped(c.primary),
    hex_stripped(c.outlineVariant),
    hex_stripped(c.surfaceContainer),
    hex_stripped(c.onSurface)
)
