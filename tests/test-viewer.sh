#!/usr/bin/env bash
# Imageviewer: file layer (test-viewer.py), launcher, desktop entry, window
# rules, command table, and the pure picture math.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$ROOT/stow/shell/.config/quickshell/modern"
VW="$QS/Modules/Viewer"
DESKTOP="$ROOT/stow/xdg/.local/share/applications/modern.imageviewer.desktop"
FAIL=0
err() { printf 'test-viewer: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-viewer: ok %s\n' "$*"; }

same() {
    if [ "$2" = "$1" ]; then ok "$3"; else err "$3 (got: $2)"; fi
}
has() {
    if grep -q "$1" "$2"; then ok "$3"; else err "$3"; fi
}

python3 "$ROOT/tests/test-viewer.py" || FAIL=1

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-viewer-sh-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/dir with space"

run() { (cd "$TMP" && MODERN_VIEWER_DRY=1 "$ROOT/scripts/modern-imageviewer" "$@"); }
same "start [\"$TMP/dir with space/a b.png\"]" "$(run "dir with space/a b.png")" "a relative path opens against the working folder"
same "start [\"$TMP/b[0] #1.png\"]" "$(run "file://$TMP/b%5B0%5D%20%231.png")" "a file:// URI is decoded"
same "start []" "$(run)" "no argument starts with the chooser"
same "start [\"$TMP/a.png\", \"$TMP\"]" "$(run a.png "" "https://example.org/x.png" .)" "empty and remote arguments are dropped"

field() { sed -n "s/^$1=//p" "$DESKTOP" | head -1; }
same "ModernOS Imageviewer" "$(field Name)" "desktop entry is ModernOS Imageviewer"
same "modern-imageviewer %F" "$(field Exec)" "desktop entry passes files"
same "modern.imageviewer" "$(field StartupWMClass)" "desktop entry matches the window class"
same "modern-imageviewer" "$(field Icon)" "desktop entry uses the system icon"
want="$(cd "$ROOT/scripts/lib" && python3 -c 'import viewer_formats as f; print(";".join(f.mime_types()) + ";")')"
same "$want" "$(field MimeType)" "desktop entry claims exactly the formats the viewer reads"
if grep -qi 'imv' "$DESKTOP"; then err "desktop entry mentions another viewer"; else ok "desktop entry names only this viewer"; fi

has 'pragma AppId modern.imageviewer' "$QS/imageviewer.qml" "imageviewer.qml sets the app id"
has 'settings.watchFiles: false' "$QS/imageviewer.qml" "a file change never reloads the window away"
has '"modern.imageviewer": *{ *nameKey: "viewer.launcherName"' "$QS/Commons/ModernApps.qml" "the launcher shows the short name"
has '"modern-imageviewer-symbolic"' "$QS/Commons/SystemIcons.qml" "the viewer joins the system icon plate"
has 'return \["modern.imageviewer"' "$QS/Commons/DesktopRoles.qml" "the viewer is the first image viewer choice"
has '"imageViewer": "modern.imageviewer.desktop"' "$ROOT/stow/modern/.config/modern/config.default.json" "the viewer is the default image viewer"
has 'property string imageViewer: "modern.imageviewer.desktop"' "$QS/Commons/Config.qml" "Config falls back to the viewer"
has '^qt6-imageformats ' "$ROOT/install/manifests/20-theming.txt" "WebP, TIFF and TGA decoding is installed"
has 'modern-imageviewer-no-blur' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" "the opaque viewer skips blur"
if grep -q 'modern.imageviewer\|modern-imageviewer' "$ROOT/stow/hypr/.config/hypr/modules/windows.lua"; then
    err "windows.lua floats the viewer; it must tile like any window"
else
    ok "the viewer tiles like any window"
fi

for lang in en de; do
    file="$ROOT/stow/modern/.config/modern/translations/$lang.json"
    while read -r id key; do
        [ "$(jq -r --arg k "$key" 'getpath($k | split(".")) // empty' "$file")" != "" ] \
            || err "$lang.json lacks $key"
        grep -qE "case \"$id\":" "$VW/Actions.qml" || err "Actions.run has no case for $id"
    done < <(sed -n 's/.*{ id: "\([^"]*\)", key: "\([^"]*\)".*/\1 \2/p' "$VW/actions.js")
    while read -r key; do
        [ "$(jq -r --arg k "$key" 'getpath($k | split(".")) // empty' "$file")" != "" ] \
            || err "$lang.json lacks $key"
    done < <(grep -rhoE '"viewer\.[A-Za-z0-9_.]+[A-Za-z0-9_]"' "$VW" "$QS/Services/ViewerDoc.qml" | tr -d '"' | sort -u)
    for e in missing directory special empty denied readOnlyFs full badName changed unsupported tooLarge protected failed; do
        [ "$(jq -r --arg e "$e" '.viewer.errors[$e] // empty' "$file")" != "" ] || err "$lang.json lacks viewer.errors.$e"
    done
done
[ "$FAIL" = 0 ] && ok "every command and message has a label in both languages and a handler"

dupes="$(sed -n 's/.*keys: \[\([^]]*\)\].*/\1/p' "$VW/actions.js" | grep -oE '"[^"]+"' | sort | uniq -d)"
same "" "$dupes" "no key is bound to two commands"

if command -v node >/dev/null 2>&1; then
    {
        grep -v '^\.pragma' "$VW/viewops.js"
        cat <<'JS'
const assert = (c, m) => { if (!c) { console.error("FAIL " + m); process.exitCode = 1; } };
const near = (a, b) => Math.abs(a - b) < 1e-9;
assert(near(fitScale(1000, 500, 4000, 1000), 0.25), "fit uses the tighter side");
assert(fitScale(0, 500, 10, 10) === 1 && fitScale(100, 100, 0, 0) === 1, "an unknown size fits at 1");
assert(baseScale("shrink", 3) === 1 && baseScale("shrink", 0.5) === 0.5, "shrink never enlarges");
assert(baseScale("fit", 3) === 3 && baseScale("actual", 0.2) === 1, "fit fills, actual is 1:1");
assert(near(zoomed(1, 1, 1), 1.25) && near(zoomed(1, -1, 1), 0.8), "one notch is a 25 % step");
assert(zoomed(30, 5, 1) === maxScale && near(zoomed(0.01, -5, 0.5), 0.5 / 8), "zoom is bounded");
assert(notches(120, 0) === 1 && notches(0, -48) === -1 && notches(0, 0) === 0, "wheel and touchpad agree");
assert(anchored(0, 50, 100, 100, 1, 2) === 50, "zooming keeps the point under the pointer");
assert(anchored(0, 50, 100, 100, 2, 0.5) === 0, "zooming out of view clamps to the start");
assert(anchored(500, 100, 100, 100, 2, 2) === 100, "the offset never runs past the end");
assert(panned(10, -50, 100, 300) === 0 && panned(150, 100, 100, 300) === 200, "panning stays inside");
assert(JSON.stringify(sizeParts(512)) === '{"value":512,"unit":"byte"}', "bytes stay bytes");
assert(JSON.stringify(sizeParts(1536)) === '{"value":1.5,"unit":"kb"}', "kilobytes keep one decimal");
assert(JSON.stringify(sizeParts(20 * 1048576)) === '{"value":20,"unit":"mb"}', "large values round");
assert(sizeParts("x") === null && sizeParts(-1) === null, "nonsense has no size");
assert(mtimeDate("1795284061415438585").getTime() === 1795284061415, "nanoseconds become a date");
assert(mtimeDate("") === null && mtimeDate("12a") === null, "a bad mtime has no date");
assert(fileUrl("/a/b #1?.png", 0) === "file:///a/b%20%231%3F.png", "a URL keeps # and ? as part of the name");
assert(fileUrl("/a.png", 3) === "file:///a.png#r3" && fileUrl("", 1) === "", "a rewrite reloads");
JS
    } >"$TMP/viewops.js"
    if node "$TMP/viewops.js"; then ok "picture fit, zoom, pan and URL helpers"; else err "viewops"; fi
    {
        grep -v '^\.pragma' "$VW/actions.js"
        cat <<'JS'
const assert = (c, m) => { if (!c) { console.error("FAIL " + m); process.exitCode = 1; } };
const items = menuItems();
assert(items.length === list.filter(a => a.menu).length, "the menu shows every menu command once");
assert(items.filter(a => a.divider).length >= 2, "menu groups are divided");
assert(bindable().every(a => a.keys.length > 0), "only commands with keys are bound");
assert(byId("next").keys.indexOf("Right") >= 0 && byId("zoomIn").keys.indexOf("Up") >= 0, "arrows step and zoom like before");
JS
    } >"$TMP/actions.js"
    if node "$TMP/actions.js"; then ok "command table"; else err "actions.js"; fi
else
    ok "node not installed; picture math checks skipped"
fi

[ "$FAIL" = 0 ] || exit 1
