-- Shared autostart window identity for session_apps (respawn) and shell hide/raise.
-- Vivaldi --app= uses URL-derived classes; StartupWMClass is ignored.

local M = {}

function M.stem(id)
    return tostring(id or ""):gsub("%.desktop$", "")
end

function M.norm(s)
    return tostring(s or ""):lower():gsub("%.desktop$", ""):gsub("[%s._%-]+", "")
end

-- needle is already norm()'d desktop stem (e.g. protonmail, whatsapp).
function M.url_tokens(needle, fieldn)
    if needle == "" or fieldn == "" then
        return false
    end
    -- "protonmail", not "mail": tradeskillmaster contains those four letters
    -- and was raised as the Proton Mail window.
    if needle:find("protonmail", 1, true)
        and (fieldn:find("mailproton", 1, true) or fieldn:find("mailprotonme", 1, true)) then
        return true
    end
    if needle:find("protoncalendar", 1, true)
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
    -- Needle inside field only. Reverse match (field inside needle) falsely
    -- tied "proton" game titles to proton-mail / proton-calendar.
    if #needle >= 5 and fieldn:find(needle, 1, true) then
        return true
    end
    return false
end

function M.window_matches(w, desktop_id)
    -- Hyprland hands windows back as userdata, not tables.
    if type(w) ~= "table" and type(w) ~= "userdata" then
        return false
    end
    local fields = {
        w.class,
        w.initial_class,
        w.initialClass,
        w.title,
        w.initial_title,
        w.initialTitle,
    }
    for _, raw in ipairs(fields) do
        if M.field_matches(raw, desktop_id) then
            return true
        end
    end
    return false
end

return M
