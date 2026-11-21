#!/usr/bin/env bash
# Dragging an application from the launcher grid onto the dock trash
# uninstalls it. app-package.sh decides which package that is and whether
# it may go; it runs against a fake pacman and fake application dirs.
# The shell side is checked by its wiring.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$ROOT/stow/shell/.config/quickshell/modern"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
FAIL=0

err() { printf 'test-app-package: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-app-package: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home/applications" "$TMP/usr/applications"
touch "$TMP/usr/applications/"{org.gnome.Nautilus,kitty,bash-tool}.desktop
touch "$TMP/home/applications/"{webapp,org.gnome.Nautilus}.desktop
cat >"$TMP/pacman" <<EOF
#!/usr/bin/env bash
case "\${3:-}" in
    "$TMP/usr/applications/org.gnome.Nautilus.desktop") echo nautilus ;;
    "$TMP/usr/applications/kitty.desktop") echo kitty ;;
    "$TMP/usr/applications/bash-tool.desktop") echo bash ;;
    *) echo "error: No package owns \$3" >&2; exit 1 ;;
esac
EOF
chmod +x "$TMP/pacman"

run() {
    MODERN_PACMAN="$TMP/pacman" XDG_DATA_HOME="$TMP/home" XDG_DATA_DIRS="$TMP/usr" \
        "$ROOT/scripts/app-package.sh" "$1"
}

expect() {
    local id="$1" want="$2" got
    got="$(run "$id")"
    if [ "$got" = "$want" ]; then ok "$id"; else err "$id: $got (want $want)"; fi
}

# The user copy shadows the packaged file; the package still owns the app.
expect org.gnome.Nautilus.desktop '{"pkg":"nautilus","removable":true,"why":""}'
expect kitty '{"pkg":"kitty","removable":false,"why":"system"}'
expect bash-tool '{"pkg":"bash","removable":false,"why":"system"}'
expect webapp '{"pkg":"","removable":false,"why":"notPackaged"}'
expect missing '{"pkg":"","removable":false,"why":"notPackaged"}'
expect '../etc/passwd' '{"pkg":"","removable":false,"why":"notPackaged"}'

grep -q 'Dock.beginGridDrag' "$QS/Modules/Launcher/AppTile.qml" \
    || err "the all-apps grid does not start a grid drag"
if grep -q 'beginGridDrag' "$QS/Modules/Launcher/Results.qml"; then
    err "search results must not offer uninstall"
fi
grep -q 'AppUninstall.drop' "$QS/Services/Dock.qml" || err "trash drop is not wired"
grep -q 'running: trash.visible && Dock.dragFromDock' "$QS/Modules/Dock/DockRow.qml" \
    || err "the trash wiggles for grid drags"
grep -q 'AppUninstall.blocked' "$QS/Modules/Dock/DockRow.qml" || err "the trash does not grey out"
grep -q 'Store.requestRemove' "$QS/Services/AppUninstall.qml" \
    || err "uninstall skips the Store confirm dialog"
grep -q '^singleton AppUninstall ' "$QS/Services/qmldir" || err "AppUninstall missing from qmldir"
for key in trash blocked busy; do
    for f in "$EN" "$DE"; do
        jq -e --arg k "$key" '.launcher.uninstall[$k] | type == "string"' "$f" >/dev/null \
            || err "launcher.uninstall.$key missing in $(basename "$f")"
    done
done
ok "shell wiring"

exit "$FAIL"
