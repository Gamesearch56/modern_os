-- Minimal, dependency-free JSON decoder for Hyprland's sandboxed Lua
-- runtime, which ships no JSON module. Decode-only — we never write JSON
-- from Lua (config.json is only ever written by the Settings app; see
-- docs/DECISIONS.md #3).
--
-- Usage: local json = require("lib.json"); local t = json.decode(str)

local json = {}

local function skip_whitespace(s, i)
    while i <= #s and s:sub(i, i):match("%s") do
        i = i + 1
    end
    return i
end

local decode_value -- forward declaration

local function decode_string(s, i)
    i = i + 1 -- skip opening quote
    local out = {}
    while true do
        local c = s:sub(i, i)
        if c == '"' then
            return table.concat(out), i + 1
        elseif c == "\\" then
            local nc = s:sub(i + 1, i + 1)
            local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
            out[#out + 1] = map[nc] or nc
            i = i + 2
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

local function decode_number(s, i)
    local start = i
    while i <= #s and s:sub(i, i):match("[%d%.eE%+%-]") do
        i = i + 1
    end
    return tonumber(s:sub(start, i - 1)), i
end

local function decode_object(s, i)
    i = i + 1 -- skip {
    local obj = {}
    i = skip_whitespace(s, i)
    if s:sub(i, i) == "}" then
        return obj, i + 1
    end
    while true do
        i = skip_whitespace(s, i)
        local key
        key, i = decode_string(s, i)
        i = skip_whitespace(s, i)
        i = i + 1 -- skip :
        i = skip_whitespace(s, i)
        local value
        value, i = decode_value(s, i)
        obj[key] = value
        i = skip_whitespace(s, i)
        local c = s:sub(i, i)
        if c == "," then
            i = i + 1
        elseif c == "}" then
            return obj, i + 1
        else
            error("json.lua: expected , or } at position " .. i)
        end
    end
end

local function decode_array(s, i)
    i = i + 1 -- skip [
    local arr = {}
    i = skip_whitespace(s, i)
    if s:sub(i, i) == "]" then
        return arr, i + 1
    end
    while true do
        i = skip_whitespace(s, i)
        local value
        value, i = decode_value(s, i)
        arr[#arr + 1] = value
        i = skip_whitespace(s, i)
        local c = s:sub(i, i)
        if c == "," then
            i = i + 1
        elseif c == "]" then
            return arr, i + 1
        else
            error("json.lua: expected , or ] at position " .. i)
        end
    end
end

decode_value = function(s, i)
    i = skip_whitespace(s, i)
    local c = s:sub(i, i)
    if c == "{" then
        return decode_object(s, i)
    elseif c == "[" then
        return decode_array(s, i)
    elseif c == '"' then
        return decode_string(s, i)
    elseif s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif s:sub(i, i + 3) == "null" then
        return nil, i + 4
    else
        return decode_number(s, i)
    end
end

function json.decode(s)
    if not s or s == "" then
        return {}
    end
    local ok, result = pcall(function()
        local value, _ = decode_value(s, 1)
        return value
    end)
    if not ok then
        return {}
    end
    return result or {}
end

return json
