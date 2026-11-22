-- Same light-glass curve as Commons/Chrome.washOpacity (Tokens.glass).
-- Near-white surfaces at design.transparency read as opaque sheets;
-- acrylic tint at 0x18 of that surface milks the compositor frost.

local config = require("modules.config")
local json = require("lib.json")

local LIFT_FROM = 0.25
local PASS_BOOST = 3.2
local MIN_WASH = 0.28
local TINT_DARK = 24
local TINT_RANGE = 22
local TINT_FLOOR = 6

local cached = nil

local function tokens()
    if cached ~= nil then
        return cached
    end
    cached = {}
    local home = os.getenv("HOME") or ""
    local f = io.open(home .. "/.config/modern/tokens.json", "r")
    if not f then
        return cached
    end
    local raw = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == "table" then
        cached = data
    end
    return cached
end

local function hex6(value)
    if type(value) ~= "string" then
        return nil
    end
    local h = value:gsub("^#", "")
    if #h ~= 6 then
        return nil
    end
    return h
end

local function luminance(hex)
    local h = hex6(hex)
    if not h then
        return 0
    end
    local r = tonumber(h:sub(1, 2), 16)
    local g = tonumber(h:sub(3, 4), 16)
    local b = tonumber(h:sub(5, 6), 16)
    if not r or not g or not b then
        return 0
    end
    return 0.2126 * (r / 255) + 0.7152 * (g / 255) + 0.0722 * (b / 255)
end

local function surface_hex()
    local data = tokens()
    local color = data.color
    if type(color) ~= "table" then
        return nil
    end
    return hex6(color.surface)
end

local function wash()
    if require("modules.light_effects") then
        return 1
    end
    local t = tonumber(config.value("design.transparency", 0.85)) or 0.85
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end
    local L = luminance(surface_hex() or "000000")
    local lift = math.max(0, L - LIFT_FROM)
    local pass = (1 - t) * (1 + lift * PASS_BOOST)
    local a = 1 - pass
    if a < MIN_WASH then
        a = MIN_WASH
    elseif a > 1 then
        a = 1
    end
    return a
end

local function acrylic_tint(surface)
    local h = hex6(surface)
    if not h then
        return "0x00000000"
    end
    local L = luminance(h)
    local a = math.floor(TINT_DARK - math.max(0, L - LIFT_FROM) * TINT_RANGE)
    if a < TINT_FLOOR then
        a = TINT_FLOOR
    elseif a > TINT_DARK then
        a = TINT_DARK
    end
    return string.format("0x%02x%s", a, h)
end

return {
    wash = wash,
    acrylic_tint = acrylic_tint,
    surface_hex = surface_hex,
}
