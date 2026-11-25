#!/usr/bin/env bash
# Manual: renderer and links (test-manual.py), launcher, desktop entry,
# shortcut, and the app's registrations.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$ROOT/stow/shell/.config/quickshell/modern"
DESKTOP="$ROOT/stow/xdg/.local/share/applications/modern.manual.desktop"
FAIL=0
err() { printf 'test-manual: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-manual: ok %s\n' "$*"; }

same() {
    if [ "$2" = "$1" ]; then ok "$3"; else err "$3 (got: $2)"; fi
}
has() {
    if grep -q "$1" "$2"; then ok "$3"; else err "$3"; fi
}

python3 "$ROOT/tests/test-manual.py" || FAIL=1

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-manual-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
run() { (cd "$TMP" && PATH="$TMP/bin:$PATH" MODERN_MANUAL_DRY=1 "$ROOT/scripts/modern-manual" "$@"); }
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho "[]"\n' >"$TMP/bin/hyprctl"
chmod +x "$TMP/bin/hyprctl"
same "start <first chapter>" "$(run)" "no window open starts one"
same "start $TMP/a b.md" "$(run "a b.md")" "a relative document opens against the working folder"
same "start $TMP/c.md" "$(run "file://$TMP/c.md")" "a file:// URI is decoded"
printf '#!/bin/sh\necho %s\n' "'[{\"class\":\"modern.manual\",\"address\":\"0xabc\"}]'" >"$TMP/bin/hyprctl"
same "focus 0xabc" "$(run)" "an open manual is focused instead of opened twice"
same "start $TMP/d.md" "$(run d.md)" "naming a document always opens it"

field() { sed -n "s/^$1=//p" "$DESKTOP" | head -1; }
same "ModernOS Manual" "$(field Name)" "desktop entry is ModernOS Manual"
same "modern-manual" "$(field Exec)" "desktop entry runs the launcher"
same "modern.manual" "$(field StartupWMClass)" "desktop entry matches the window class"
same "modern-manual" "$(field Icon)" "desktop entry uses the system icon"

has 'pragma AppId modern.manual' "$QS/manual.qml" "manual.qml sets the app id"
has 'settings.watchFiles: false' "$QS/manual.qml" "a file change never reloads the window away"
has '"modern.manual": *{ *nameKey: "manual.launcherName"' "$QS/Commons/ModernApps.qml" "the launcher shows the short name"
has '"modern-manual-symbolic"' "$QS/Commons/SystemIcons.qml" "the manual joins the system icon plate"
has '^singleton ManualDocs ' "$QS/Services/qmldir" "ManualDocs is registered"
has 'manual = hl.dsp.exec_cmd(paths.scripts .. "/modern-manual")' "$ROOT/stow/hypr/.config/hypr/modules/keybinds.lua" "the manual has a bind"
same '"SUPER + Y"' "$(jq '.keybinds.manual' "$ROOT/stow/modern/.config/modern/config.default.json")" "SUPER + Y opens the manual"
has 'manual: "SUPER + Y"' "$QS/Commons/Config.qml" "Config falls back to SUPER + Y"
has 'manual: "system"' "$QS/Services/CheatsheetModel.qml" "the shortcut sheet lists the manual under System"
has 'manual: "SUPER + Y"' "$QS/Services/CheatsheetModel.qml" "the sheet shows the shortcut on an older config.json"
has 'acceptedButtons: Qt.BackButton' "$QS/Modules/Manual/ManualWindow.qml" "the mouse back button goes back"
has 'acceptedButtons: Qt.ForwardButton' "$QS/Modules/Manual/ManualWindow.qml" "the mouse forward button goes forward"
if grep -q 'sequences:.*StandardKey\.\(Back\|Forward\)' "$QS/Modules/Manual/ManualWindow.qml"; then
    err "StandardKey.Back/Forward doubles Alt+Left/Right and makes the shortcut ambiguous"
else
    ok "Alt+Left and Alt+Right are bound once"
fi
if grep -q 'modern.manual\|modern-manual' "$ROOT/stow/hypr/.config/hypr/modules/windows.lua"; then
    err "windows.lua floats the manual; it must tile like any window"
else
    ok "the manual tiles like any window"
fi

for lang in en de; do
    file="$ROOT/stow/modern/.config/modern/translations/$lang.json"
    for key in manual.title manual.launcherName manual.windowTitle manual.search manual.groups.manual \
        manual.groups.reference manual.back manual.forward manual.contents manual.onThisPage manual.chapter manual.link \
        manual.sections.start manual.sections.system manual.sections.more cheatsheet.action.manual; do
        if [ -n "$(jq -r --arg k "$key" 'getpath($k | split(".")) // empty' "$file")" ]; then
            ok "$lang has $key"
        else
            err "$lang is missing $key"
        fi
    done
done

# The installed checkout is sparse; without docs/ the Manual lists only
# README and CONTRIBUTING.
if grep -Eq 'sparse-checkout set --cone .*\bdocs\b' "$ROOT/scripts/iso-build.sh"; then
    ok "the ISO bundle checks out docs/"
else
    err "the ISO bundle must check out docs/ for the Manual"
fi
if grep -Fq 'sparse-checkout add docs' "$ROOT/scripts/desktop-sync.sh"; then
    ok "an update adds docs/ to an older sparse checkout"
else
    err "desktop-sync must add docs/ to a sparse checkout"
fi

exit "$FAIL"
