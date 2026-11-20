#!/usr/bin/env bash
# Dock contract: defaults, the mirrored edge, names, and the locked drag.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT="$ROOT/stow/modern/.config/modern/config.default.json"
LAYOUT="$ROOT/stow/shell/.config/quickshell/modern/Commons/DockLayout.qml"
CONFIG="$ROOT/stow/shell/.config/quickshell/modern/Commons/Config.qml"
CATALOG="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/Catalog.qml"
PIN="$ROOT/stow/shell/.config/quickshell/modern/Modules/Dock/DockPin.qml"
TRASH="$ROOT/stow/shell/.config/quickshell/modern/Modules/Dock/DockRow.qml"
DOCK="$ROOT/stow/shell/.config/quickshell/modern/Services/Dock.qml"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
FAIL=0

err() { printf 'test-dock: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-dock: ok %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

enabled="$(jq -r '.dock.enabled' "$DEFAULT")"
auto_hide="$(jq -r '.dock.autoHide' "$DEFAULT")"
show_names="$(jq -r '.dock.showNames' "$DEFAULT")"
theme="$(jq -r '.dock.theme' "$DEFAULT")"
icon_size="$(jq -r '.dock.iconSize' "$DEFAULT")"
apps="$(jq -c '.dock.apps' "$DEFAULT")"

if [ "$enabled" = "false" ] && [ "$auto_hide" = "false" ] && [ "$show_names" = "false" ] \
    && [ "$theme" = "floating" ] && [ "$icon_size" = "48" ] && [ "$apps" = "[]" ]; then
    ok "dock defaults are off, floating, icon size 48, and empty"

if grep -Fq 'readonly property alias dock: adapter.dock' "$CONFIG"; then
    ok "dock settings are read from config.json"
else
    err "Config.qml must alias adapter.dock or the saved switch never sticks"
fi
else
    err "dock defaults are enabled=$enabled autoHide=$auto_hide showNames=$show_names theme=$theme iconSize=$icon_size apps=$apps"
fi

if grep -Fq 'if (edge === "bottom")' "$LAYOUT" \
    && grep -Fq 'return "top"' "$LAYOUT" \
    && grep -Fq 'if (edge === "left")' "$LAYOUT" \
    && grep -Fq 'return "right"' "$LAYOUT" \
    && grep -Fq 'if (edge === "right")' "$LAYOUT" \
    && grep -Fq 'return "left"' "$LAYOUT" \
    && grep -Fq 'return "bottom"' "$LAYOUT"; then
    ok "the dock edge mirrors the bar"
else
    err "DockLayout must map top to bottom, bottom to top, left to right, and right to left"
fi

if grep -Fq 'Accessible.role: Accessible.Button' "$PIN" \
    && grep -Fq 'Accessible.name: root.label' "$PIN" \
    && grep -Fq 'Accessible.onPressAction: root._open()' "$PIN" \
    && grep -Fq 'Dock.launch(root.appId)' "$PIN" \
    && grep -Fq 'canDrag: Launcher.open' "$PIN" \
    && ! grep -Fq 'Dock.showTip' "$PIN"; then
    ok "a pin is a named button, and a drag starts only while the launcher is open"
else
    err "DockPin must name the button, skip the hover label, and lock dragging"
fi

if grep -Fq 'Hypr.raiseDesktopOrLaunch' "$DOCK"; then
    ok "a dock click brings a background app onto this workspace"
else
    err "dock launch must raise a parked window, not only gtk-launch it"
fi

if grep -Fq 'dragFromDock' "$TRASH" \
    && grep -Fq 'settings.dock.trash' "$TRASH" \
    && grep -Fq 'kind === "trash" && fromDock' "$DOCK"; then
    ok "only a drop on the trash removes a dock pin"
else
    err "the trash target must be named, and only a dock-pin drop on it removes the pin"
fi

for key in settings.sections.dock settings.dock.enable settings.dock.trash settings.dock.remove; do
    jq -e --arg k "$key" 'getpath($k | split(".")) | type == "string"' "$EN" >/dev/null \
        || err "en.json missing $key"
    jq -e --arg k "$key" 'getpath($k | split(".")) | type == "string"' "$DE" >/dev/null \
        || err "de.json missing $key"
done
ok "dock strings exist in English and German"

if grep -Fq 'restore: ["dock.autoHide", "dock.iconSize", "dock.showNames", "dock.pad", "dock.gap", "dock.theme", "dock.hover"]' "$CATALOG" \
    && ! grep -Fq 'dock.enabled' "$CATALOG" \
    && grep -Fq 'on_GenerationChanged' "$LAYOUT"; then
    ok "dock restore resets the switches, keeps the dock switch, and keeps pinned applications"
else
    err "dock restore must reset each setting except dock.enabled and dock.apps, and drop the live preview"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
