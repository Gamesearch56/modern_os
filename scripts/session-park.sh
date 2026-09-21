#!/usr/bin/env bash
# Move general.autostart Vivaldi web-app windows onto special:background.
# Used by session_apps.lua when exec_cmd workspace rules miss forked Chromium.
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
DEFAULT="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.default.json"
if [[ -f "$CFG" ]]; then
    SRC="$CFG"
elif [[ -f "$DEFAULT" ]]; then
    SRC="$DEFAULT"
else
    exit 0
fi

mapfile -t IDS < <(jq -r '.general.autostart // [] | .[]' "$SRC" 2>/dev/null || true)
if [[ ${#IDS[@]} -eq 0 ]]; then
    exit 0
fi

needles=()
for id in "${IDS[@]}"; do
    stem="${id%.desktop}"
    stem="${stem,,}"
    stem="${stem//[^a-z0-9]/}"
    needles+=("$stem")
    case "$stem" in
        *mail*) needles+=("mailproton" "mail.proton") ;;
        *calendar*) needles+=("calendarproton" "calendar.proton") ;;
        *whatsapp*) needles+=("whatsapp" "web.whatsapp") ;;
    esac
done

hyprctl -j clients 2>/dev/null | jq -r --argjson n "$(printf '%s\n' "${needles[@]}" | jq -R . | jq -s .)" '
  .[] | select(.workspace.name | tostring | test("special:background") | not) |
  . as $w |
  ($w.class // "") + " " + ($w.initialClass // "") + " " + ($w.title // "") |
  ascii_downcase |
  . as $hay |
  select(any($n[]; . != "" and ($hay | contains(.)))) |
  $w.address
' 2>/dev/null | while read -r addr; do
    [[ -n "$addr" ]] || continue
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:background\", silent = true, window = \"address:${addr}\" })" >/dev/null || true
done
