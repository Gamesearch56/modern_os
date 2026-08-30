-- XKB keycodes (evdev + 8) for binds whose keysyms differ on de/us.
-- Number row 10–19 is the same on both; letter names are not.

local M = {}

function M.number_row_code(n)
    if n == 10 then
        return "code:19"
    end
    return "code:" .. tostring(9 + n)
end

function M.default_number_combo(n, shift)
    local digit = (n == 10) and "0" or tostring(n)
    if shift then
        return "SUPER + SHIFT + " .. digit
    end
    return "SUPER + " .. digit
end

-- action -> { combo, code_bind }
M.named = {
    aiChat = { combo = "SUPER + A", bind = "SUPER + code:38" },
    taskbar = { combo = "SUPER + DELETE", bind = "SUPER + code:119" },
}

return M
