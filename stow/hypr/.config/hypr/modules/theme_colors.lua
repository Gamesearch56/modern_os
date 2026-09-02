-- Border colors. Prefer the matugen file (gitignored
-- `modules/colors.lua`); checking out a commit that `git rm`'d that
-- tracked file used to abort hyprland.lua and leave the emergency
-- overlay. tokens.json is the same palette.

local json = require("lib.json")

local function hex_stripped(value)
    if type(value) ~= "string" then
        return nil
    end
    return (value:gsub("^#", ""))
end

local function apply(primary, outline)
    if not primary or not outline then
        return {}
    end
    hl.config({
        general = {
            ["col.active_border"] = "rgba(" .. primary .. "ff)",
            ["col.inactive_border"] = "rgba(" .. outline .. "ff)",
        },
    })
    return {}
end

local ok, generated = pcall(require, "modules.colors")
if ok then
    return generated
end

local home = os.getenv("HOME") or ""
local f = io.open(home .. "/.config/modern/tokens.json", "r")
if not f then
    return {}
end
local raw = f:read("*a")
f:close()

ok, generated = pcall(json.decode, raw)
if not ok or type(generated) ~= "table" or type(generated.color) ~= "table" then
    return {}
end

local c = generated.color
return apply(hex_stripped(c.primary), hex_stripped(c.outlineVariant))
