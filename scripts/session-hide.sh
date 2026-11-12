#!/usr/bin/env bash
# Park focused (or given) window on special:background when it matches
# general.autostart. Super+Q fallback when Quickshell miss-matches.
# Exit 0 if parked, 1 otherwise. Never parks unrelated clients.
set -euo pipefail

addr="${1:-}"
if [[ -z "$addr" || "$addr" == "focused" ]]; then
    addr="$(hyprctl -j activewindow 2>/dev/null | jq -r '.address // empty')"
fi
addr="${addr#address:}"
if [[ -z "$addr" || "$addr" == "null" ]]; then
    exit 1
fi

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
def="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.default.json"
if [[ -f "$cfg" ]]; then
    mapfile -t ids < <(jq -r '(.general.autostart // [])[]?' "$cfg" 2>/dev/null || true)
fi
if [[ ${#ids[@]} -eq 0 && -f "$def" ]]; then
    mapfile -t ids < <(jq -r '(.general.autostart // [])[]?' "$def" 2>/dev/null || true)
fi
if [[ ${#ids[@]} -eq 0 ]]; then
    exit 1
fi

hay="$(hyprctl -j clients 2>/dev/null | jq -r --arg a "$addr" '
  .[] | select((.address // "") == $a) |
  ((.class // "") + " " + (.initialClass // "") + " " + (.title // "") + " " + (.initialTitle // ""))
  | ascii_downcase
' | head -n1)"
if [[ -z "$hay" ]]; then
    exit 1
fi

norm() {
    local s="${1,,}"
    s="${s%.desktop}"
    s="${s//[^a-z0-9]/}"
    printf '%s' "$s"
}

field_ok() {
    local fieldn needle
    fieldn="$(norm "$1")"
    needle="$(norm "$2")"
    [[ -z "$fieldn" || -z "$needle" ]] && return 1
    if [[ "$needle" == *protonmail* && ( "$fieldn" == *mailproton* || "$fieldn" == *mailprotonme* ) ]]; then
        return 0
    fi
    if [[ "$needle" == *protoncalendar* && ( "$fieldn" == *calendarproton* || "$fieldn" == *calendarprotonme* ) ]]; then
        return 0
    fi
    if [[ "$needle" == *whatsapp* && ( "$fieldn" == *whatsapp* || "$fieldn" == *webwhatsapp* ) ]]; then
        return 0
    fi
    [[ "$fieldn" == "$needle" ]] && return 0
    if [[ ${#needle} -ge 5 && "$fieldn" == *"$needle"* ]]; then
        return 0
    fi
    return 1
}

matched=0
for id in "${ids[@]}"; do
    if field_ok "$hay" "$id"; then
        matched=1
        break
    fi
done
if [[ "$matched" -ne 1 ]]; then
    exit 1
fi

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$dir/background-move.sh" "$addr"
