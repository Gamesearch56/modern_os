-- Reads config.json (falling back to config.default.json) so
-- hyprland.lua's other modules never hardcode a value the Settings app
-- is supposed to control. Read-only: Lua never writes this file (see
-- docs/DECISIONS.md #3 — the Settings app is the only writer).

local json = require("lib.json")

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

local function home()
    return os.getenv("HOME")
end

local M = {}

-- Deep-merges override table onto base table (override wins), returning
-- a new table. Arrays are replaced wholesale, not merged element-wise.
local function deep_merge(base, override)
    if type(base) ~= "table" or type(override) ~= "table" then
        return override
    end
    -- treat as array if override has sequential integer keys starting at 1
    if override[1] ~= nil then
        return override
    end
    local result = {}
    for k, v in pairs(base) do
        result[k] = v
    end
    for k, v in pairs(override) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = deep_merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

local cache = nil

-- config.get() returns the fully merged config table (default <- live).
-- Cached per Hyprland config reload (ConfigWatcher re-requires this
-- module, resetting the cache).
function M.get()
    if cache then
        return cache
    end

    local default_path = home() .. "/.config/modern/config.default.json"
    local live_path = home() .. "/.config/modern/config.json"

    local default_raw = read_file(default_path)
    local live_raw = read_file(live_path)

    local default_tbl = default_raw and json.decode(default_raw) or {}
    local live_tbl = live_raw and json.decode(live_raw) or {}

    cache = deep_merge(default_tbl, live_tbl)
    return cache
end

-- Dot-path getter with a default, e.g. config.value("bar.height", 40).
function M.value(path, fallback)
    local tbl = M.get()
    for segment in path:gmatch("[^.]+") do
        if type(tbl) ~= "table" then
            return fallback
        end
        tbl = tbl[segment]
    end
    if tbl == nil then
        return fallback
    end
    return tbl
end

return M
