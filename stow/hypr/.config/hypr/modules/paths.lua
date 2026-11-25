-- Repo and script locations. Hyprland Lua must not concatenate
-- `$HOME/modern_os/scripts` in every module.
-- Live path: $XDG_CONFIG_HOME/modern/repo (one line, written by install.sh).
-- Fallback: $HOME/modern_os (ISO Calamares clone location).

local home = os.getenv("HOME") or ""

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    line = trim(line)
    if line == "" then
        return nil
    end
    return line
end

local function config_home()
    local xdg = os.getenv("XDG_CONFIG_HOME")
    if xdg and xdg ~= "" then
        return xdg
    end
    return home .. "/.config"
end

local function has_scripts(repo)
    if not repo or repo == "" then
        return false
    end
    local f = io.open(repo .. "/scripts/modern-launch", "r")
    if not f then
        return false
    end
    f:close()
    return true
end

local function resolve_repo()
    -- Prefer a path that actually exists. A stale MODERN_REPO from
    -- hl.env at session start (or a missing ~/modern_os) must not
    -- win over ~/.config/modern/repo.
    local candidates = {
        trim(os.getenv("MODERN_REPO")),
        read_first_line(config_home() .. "/modern/repo") or "",
        home .. "/modern_os",
    }
    for i = 1, #candidates do
        if has_scripts(candidates[i]) then
            return candidates[i]
        end
    end
    for i = 1, #candidates do
        if candidates[i] ~= "" then
            return candidates[i]
        end
    end
    return home .. "/modern_os"
end

local repo = resolve_repo()

return {
    home = home,
    repo = repo,
    scripts = repo .. "/scripts",
    modern = repo .. "/scripts/modern",
    modern_launch = repo .. "/scripts/modern-launch",
}
