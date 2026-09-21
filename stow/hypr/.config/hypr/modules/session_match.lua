-- Shared autostart window identity for session_apps (park / respawn).
-- Vivaldi --app= uses URL-derived classes; StartupWMClass is ignored.

local M = {}

function M.stem(id)
    return tostring(id or ""):gsub("%.desktop$", "")
end

function M.norm(s)
    return tostring(s or ""):lower():gsub("%.desktop$", ""):gsub("[%s._%-]+", "")
end

-- needle is already norm()'d desktop stem (e.g. protonmail).
function M.url_tokens(needle, fieldn)
    if needle == "" or fieldn == "" then
        return false
    end
    if needle:find("mail", 1, true)
        and (fieldn:find("mailproton", 1, true) or fieldn:find("mailprotonme", 1, true)) then
        return true
    end
    if needle:find("calendar", 1, true)
        and (fieldn:find("calendarproton", 1, true) or fieldn:find("calendarprotonme", 1, true)) then
        return true
    end
    if needle:find("whatsapp", 1, true)
        and (fieldn:find("whatsapp", 1, true) or fieldn:find("webwhatsapp", 1, true)) then
        return true
    end
    return false
end

function M.field_matches(raw, desktop_id)
    local needle = M.norm(desktop_id)
    local fieldn = M.norm(raw)
    if needle == "" or fieldn == "" then
        return false
    end
    if M.url_tokens(needle, fieldn) then
        return true
    end
    if fieldn == needle then
        return true
    end
    if #needle >= 5 and fieldn:find(needle, 1, true) then
        return true
    end
    if #fieldn >= 5 and needle:find(fieldn, 1, true) then
        return true
    end
    return false
end

function M.window_matches(w, desktop_id)
    if type(w) ~= "table" then
        return false
    end
    local fields = {
        w.class,
        w.initial_class,
        w.title,
        w.initial_title,
    }
    for _, raw in ipairs(fields) do
        if M.field_matches(raw, desktop_id) then
            return true
        end
    end
    return false
end

return M
