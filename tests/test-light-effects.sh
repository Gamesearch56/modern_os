#!/usr/bin/env bash
# Settings -> Gaming -> Performance drops blur, shadows and wobble across
# the desktop. general.lua and glass.lua run against a mock hl; the
# shell side is checked by its wiring.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR="$ROOT/stow/hypr/.config/hypr"
QS="$ROOT/stow/shell/.config/quickshell/modern"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
FAIL=0

err() { printf 'test-light-effects: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-light-effects: ok %s\n' "$*"; }

LUA="$(command -v lua5.4 || command -v lua || true)"
[ -n "$LUA" ] || { echo "lua required" >&2; exit 1; }

# Prints blur shadow wobble opacity scanout tearing layer-rule wash.
run() {
    (cd "$HYPR" && "$LUA" - "$1" "$2" <<'LUA'
local light, blur = arg[1] == "true", tonumber(arg[2])
package.path = "./?.lua;" .. package.path
-- A CI runner is a VM; the soft-GPU probe must not decide this test.
local real_open = io.open
io.open = function(path, ...)
    if path:find("^/sys/") or path:find("^/proc/") or path:find("tokens%.json$") then
        return nil
    end
    return real_open(path, ...)
end
local values = {
    ["gaming.autoOptimize"] = light,
    ["design.blurStrength"] = blur,
    ["windows.opacity"] = 0.9,
    ["design.transparency"] = 0.85,
}
package.preload["modules.config"] = function()
    return { value = function(p, fallback)
        local v = values[p]
        if v == nil then return fallback end
        return v
    end }
end
local cfg, rule = {}, ""
hl = {
    env = function() end,
    config = function(t)
        for k, v in pairs(t) do cfg[k] = v end
    end,
    layer_rule = function(r) rule = r.name end,
}
require("modules.general")
local d, r, g = cfg.decoration, cfg.render, cfg.general
print(tostring(d.blur.enabled), tostring(d.shadow.enabled), tostring(d.wobble.enabled),
    d.active_opacity, r.direct_scanout, tostring(g.allow_tearing), rule,
    require("modules.glass").wash() == 1 and "opaque" or "glass")
LUA
    )
}

expect() {
    local label="$1" want="$2" got
    got="$(run "$3" "$4" | tr '\t' ' ')"
    if [ "$got" = "$want" ]; then
        ok "$label"
    else
        err "$label: want '$want', got '$got'"
    fi
}

expect "effects stay as designed when the switch is off" \
    "true true true 0.9 0 false quickshell-blur glass" false 40
expect "the switch drops blur, shadows and wobble, and makes windows opaque" \
    "false false false 1 2 true quickshell-noblur opaque" true 40
expect "blur strength 0 skips the blur passes" \
    "false true true 0.9 0 false quickshell-noblur glass" false 0

if grep -Fq 'lightEffects: Config.gaming.autoOptimize === true' "$QS/Commons/Chrome.qml" \
    && grep -Fq 'if (root.lightEffects)' "$QS/Commons/Chrome.qml" \
    && grep -Fq '!Chrome.lightEffects' "$QS/Widgets/MCard.qml"; then
    ok "shell panels turn opaque and cards drop their texture layer"
else
    err "Chrome.lightEffects must make the wash opaque and MCard must skip its layer"
fi

if grep -Fq 'whole desktop' "$EN" && grep -Fq 'ganzen Desktop' "$DE"; then
    ok "the hint says the switch covers the whole desktop"
else
    err "settings.hints.easePc must say it applies to the whole desktop (en + de)"
fi

exit "$FAIL"
