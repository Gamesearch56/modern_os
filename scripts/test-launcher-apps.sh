#!/usr/bin/env bash
# The launcher's own button opens every installed app, in the same words
# in both languages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-launcher-apps: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-launcher-apps: ok %s\n' "$*"; }

LAUNCHER="$ROOT/stow/shell/.config/quickshell/modern/Services/Launcher.qml"
ALL="$ROOT/stow/shell/.config/quickshell/modern/Modules/Launcher/AllApps.qml"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"

if grep -Fq 'function catalog' "$LAUNCHER" \
    && grep -Fq 'function _matches' "$LAUNCHER"; then
    ok "the full app list is separate from the short list"
else
    err "Launcher.qml must expose catalog() for every installed app"
fi

if grep -Fq 'view-app-grid-symbolic' "$ALL" \
    && grep -Fq 'launcher.allApps' "$ALL" \
    && grep -Fq 'AppTile' "$ALL"; then
    ok "all applications is its own grid button"
else
    err "AllApps.qml must be a grid opened from its own button"
fi

if grep -Fq '"allApps": "All applications"' "$EN" \
    && grep -Fq '"allApps": "Alle Anwendungen"' "$DE"; then
    ok "the button name exists in English and German"
else
    err "launcher.allApps must be translated in en and de"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-launcher-apps: ok\n'
