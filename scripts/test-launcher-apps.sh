#!/usr/bin/env bash
# The launcher's own button opens every installed app, in the same words
# in both languages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-launcher-apps: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-launcher-apps: ok %s\n' "$*"; }

LAUNCHER="$ROOT/stow/shell/.config/quickshell/modern/Services/Launcher.qml"
MODULE="$ROOT/stow/shell/.config/quickshell/modern/Modules/Launcher/Module.qml"
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

if grep -Fq 'shell:settings' "$MODULE" \
    && grep -Fq 'shell:store' "$MODULE" \
    && grep -Fq 'shell:files' "$MODULE" \
    && grep -Fq 'kind: "files"' "$MODULE" \
    && grep -Fq 'Files.show' "$MODULE"; then
    ok "settings, the store, and the file manager are in the full list"
else
    err "the full list must include settings, the store, and the file manager"
fi

PRUNE="$ROOT/stow/shell/.config/quickshell/modern/Services/AppsPrune.qml"
APPS="$ROOT/stow/shell/.config/quickshell/modern/Services/Apps.qml"
if grep -Fq 'singleton AppsPrune 1.0 AppsPrune.qml' \
        "$ROOT/stow/shell/.config/quickshell/modern/Services/qmldir" \
    && grep -Fq 'Object.keys(have).length === 0' "$PRUNE" \
    && grep -Fq 'indexOf("shell:") === 0' "$PRUNE" \
    && grep -Fq 'ConfigWrite.set("dock.apps"' "$PRUNE" \
    && grep -Fq 'ConfigWrite.set("general.autostart"' "$PRUNE" \
    && grep -Fq 'apps.defaults.' "$PRUNE" \
    && grep -Fq 'Launcher.dropMissing' "$PRUNE" \
    && grep -Fq 'function dropMissing' "$LAUNCHER" \
    && grep -Fq 'void AppsPrune.rev' "$LAUNCHER" \
    && grep -Fq 'void AppsPrune.rev' "$APPS"; then
    ok "a removed desktop file leaves the dock, autostart, defaults, and the launcher"
else
    err "removing an app must drop it from the dock, autostart, defaults, and launcher lists"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-launcher-apps: ok\n'
