#!/usr/bin/env bash
# Print one existing directory chosen in a native folder dialog.
# Used by Services/FilePick.qml so Settings never spawns kdialog.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../install/lib/i18n.sh
source "$REPO_ROOT/install/lib/i18n.sh"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
if [ -f "$CFG" ] && command -v jq >/dev/null 2>&1; then
    I18N_LANG="$(jq -r '.language.ui // "en"' "$CFG")"
    [ "$I18N_LANG" = "de" ] || I18N_LANG="en"
fi

START="$(expand_home "${1:-}")"
if [ -n "$START" ] && [ ! -d "$START" ]; then
    START="$(dirname "$START")"
fi
if [ -z "$START" ] || [ ! -d "$START" ]; then
    START="$HOME"
fi

title="$(t folderPicker.title)"
chosen=""
if command -v kdialog >/dev/null 2>&1; then
    chosen="$(kdialog --title "$title" --getexistingdirectory "$START" || true)"
elif command -v zenity >/dev/null 2>&1; then
    chosen="$(zenity --file-selection --directory --title="$title" --filename="${START}/" || true)"
else
    t folderPicker.needChooser >&2
    exit 3
fi

if [ -z "$chosen" ]; then
    exit 1
fi
if [ ! -d "$chosen" ]; then
    echo "pick-directory: not a directory: $chosen" >&2
    exit 3
fi

printf '%s\n' "$(realpath "$chosen")"
