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

raw="${desktop,,}"
stem="${raw//[^a-z0-9]/}"
if [[ ${#stem} -lt 3 ]]; then
    exit 1
fi

# Exact class match. A compacted id (orggnomenautilus) never appears in
# "org.gnome.Nautilus", and contains() would also grab the previewer.
exacts=("$raw")
base="${raw##*.}"
if [[ "$base" != "$raw" && ${#base} -ge 5 ]]; then
    exacts+=("$base")
fi

# spotify-launcher.desktop starts class "spotify". The desktop id never
# appears in the window class, so Super+R would launch a second copy.
dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
IFS=:
for d in $dirs; do
    path="$d/applications/${desktop}.desktop"
    if [[ -f "$path" ]]; then
        wm="$(grep -i '^StartupWMClass=' "$path" | head -n1 || true)"
        wm="${wm#*=}"
        wm="${wm,,}"
        wm="${wm//[[:space:]]/}"
        if [[ ${#wm} -ge 3 ]]; then
            exacts+=("$wm")
        fi
        break
    fi
done
unset IFS

needles=("$stem")
case "$stem" in
    *mail*) needles+=("mailproton" "mail.proton" "mailprotonme" "vivaldi-mail.proton") ;;
    *calendar*) needles+=("calendarproton" "calendar.proton" "calendarprotonme" "vivaldi-calendar.proton") ;;
    *whatsapp*) needles+=("web.whatsapp" "webwhatsapp" "vivaldi-web.whatsapp") ;;
esac

clients_json() {
    if [[ -n "${MODERN_RAISE_CLIENTS:-}" && -f "$MODERN_RAISE_CLIENTS" ]]; then
        cat "$MODERN_RAISE_CLIENTS"
        return
    fi
    hyprctl -j clients 2>/dev/null || true
}

addr="$(clients_json | jq -r \
    --argjson n "$(printf '%s\n' "${needles[@]}" | jq -R . | jq -s .)" \
    --argjson exact "$(printf '%s\n' "${exacts[@]}" | jq -R . | jq -s .)" '
  .[] |
  . as $w |
  (($w.class // "") | ascii_downcase) as $cls |
  (($w.initialClass // "") | ascii_downcase) as $icls |
  ((($w.class // "") + " " + ($w.initialClass // "") + " " + ($w.title // "") + " " + ($w.initialTitle // ""))
    | ascii_downcase) as $hay |
  select(
    any($exact[]; . == $cls or . == $icls or . == ($cls | split(".") | last) or . == ($icls | split(".") | last))
    or any($n[]; . as $needle | ($needle | length) >= 3 and ($hay | contains($needle)))
  ) |
  $w.address
' 2>/dev/null | head -n1)"

if [[ -z "$addr" ]]; then
    exit 1
fi

if [[ "${MODERN_RAISE_DRY:-}" == "1" ]]; then
    printf '%s\n' "$addr"
    exit 0
fi

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

hyprctl dispatch "hl.dsp.window.move({ workspace = ${ws}, follow = true, window = \"address:${addr}\" })" >/dev/null
hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })" >/dev/null
exit 0
