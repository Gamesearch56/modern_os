#!/usr/bin/env bash
# Wallpapers, Keyboard, and Report are applications, the same way the
# Manual is: a desktop file, a short name, and a launcher script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-shell-apps: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-shell-apps: ok %s\n' "$*"; }

APPS="$ROOT/stow/xdg/.local/share/applications"
MODERN="$ROOT/stow/shell/.config/quickshell/modern/Commons/ModernApps.qml"
ICONS="$ROOT/stow/shell/.config/quickshell/modern/Commons/SystemIcons.qml"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
CARD="$ROOT/stow/shell/.config/quickshell/modern/Modules/Overview/WindowCard.qml"

field() {
    sed -n "s/^$2=//p" "$1" | head -n 1
}

check_app() {
    local id="$1" exec_name="$2" key="$3" title="$4" script_needle="$5"
    local desk="$APPS/modern.$id.desktop"
    local script="$ROOT/scripts/modern-$exec_name"
    if [ -x "$script" ] && grep -Fq "$script_needle" "$script"; then
        ok "$id launcher opens the shell window"
    else
        err "$id launcher must be executable and open the shell window"
    fi
    if [ "$(field "$desk" Exec)" = "modern-$exec_name" ] \
        && [ "$(field "$desk" StartupWMClass)" = "modern.$id" ] \
        && [ "$(field "$desk" Icon)" = "modern-$exec_name" ]; then
        ok "$id desktop entry matches the window"
    else
        err "$id desktop entry is wrong"
    fi
    if grep -Fq "\"modern.$id\": { nameKey: \"$key\"" "$MODERN" \
        && grep -Fq "modern-$exec_name-symbolic" "$ICONS" \
        && jq -e --arg k "$key" 'getpath($k | split(".")) | length > 0' "$EN" >/dev/null \
        && jq -e --arg k "$key" 'getpath($k | split(".")) | length > 0' "$DE" >/dev/null \
        && grep -Fq "modern.$title" "$CARD"; then
        ok "$id has a short name in both languages"
    else
        err "$id must have a short name, an icon, and an overview label"
    fi
}

check_app wallpaper wallpaper wallpaper.launcherName wallpaper 'ipc call wallpaper pick'
check_app cheatsheet cheatsheet cheatsheet.launcherName cheatsheet 'ipc call cheatsheet open'
check_app bugreport bugreport bugReport.launcherName bugreport 'modern" report'

[ "$FAIL" -eq 0 ]
