#!/usr/bin/env bash
# Raise a desktop id's window (often on special:background) to the active
# workspace and focus it. Used when Quickshell's toplevel list misses
# special-workspace clients. Exit 0 if a window was raised, 1 otherwise.
#
# jq gotcha: `$hay | contains(.)` rebinds `.` to $hay, so contains is always
# true — always bind the needle with `as $needle` first.
set -euo pipefail

desktop="${1:-}"
desktop="${desktop%.desktop}"
if [[ -z "$desktop" ]]; then
    exit 1
fi

stem="${desktop,,}"
stem="${stem//[^a-z0-9]/}"
if [[ ${#stem} -lt 3 ]]; then
    exit 1
fi

needles=("$stem")
case "$stem" in
    *mail*) needles+=("mailproton" "mail.proton" "mailprotonme" "vivaldi-mail.proton") ;;
    *calendar*) needles+=("calendarproton" "calendar.proton" "calendarprotonme" "vivaldi-calendar.proton") ;;
    *whatsapp*) needles+=("web.whatsapp" "webwhatsapp" "vivaldi-web.whatsapp") ;;
esac

aw="$(hyprctl -j activeworkspace 2>/dev/null || true)"
ws="$(printf '%s' "$aw" | jq -r '.id // empty')"
mon="$(printf '%s' "$aw" | jq -r '.monitor // empty')"
if [[ -z "$ws" || "$ws" == "null" ]]; then
    exit 1
fi

# Keep special:background on the active output so a later park does not
# reopen the secondary-monitor / workspace-6 path.
if [[ -n "$mon" && "$mon" != "null" ]]; then
    hyprctl dispatch "hl.dsp.workspace.move({ workspace = \"special:background\", monitor = \"${mon}\" })" >/dev/null 2>&1 || true
fi

addr="$(hyprctl -j clients 2>/dev/null | jq -r --argjson n "$(printf '%s\n' "${needles[@]}" | jq -R . | jq -s .)" '
  .[] |
  . as $w |
  ((($w.class // "") + " " + ($w.initialClass // "") + " " + ($w.title // "") + " " + ($w.initialTitle // ""))
    | ascii_downcase) as $hay |
  select(any($n[]; . as $needle | ($needle | length) >= 3 and ($hay | contains($needle)))) |
  $w.address
' 2>/dev/null | head -n1)"

if [[ -z "$addr" ]]; then
    exit 1
fi

hyprctl dispatch "hl.dsp.window.move({ workspace = ${ws}, follow = true, window = \"address:${addr}\" })" >/dev/null
hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })" >/dev/null
exit 0
