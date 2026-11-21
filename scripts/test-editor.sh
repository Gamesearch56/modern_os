#!/usr/bin/env bash
# Texteditor: file layer (test-editor.py), launcher, desktop entry, window
# size, command table, and the pure text helpers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$ROOT/stow/shell/.config/quickshell/modern"
ED="$QS/Modules/Editor"
DESKTOP="$ROOT/stow/xdg/.local/share/applications/modern.editor.desktop"
FAIL=0
err() { printf 'test-editor: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-editor: ok %s\n' "$*"; }

python3 "$ROOT/scripts/test-editor.py" || FAIL=1

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-editor-sh-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export MODERN_EDITOR_RUNTIME="$TMP/run"
mkdir -p "$TMP/dir with space"
printf 'x\n' >"$TMP/dir with space/a b.txt"

same() {
    if [ "$2" = "$1" ]; then ok "$3"; else err "$3 (got: $2)"; fi
}
has() {
    if grep -q "$1" "$2"; then ok "$3"; else err "$3"; fi
}

out="$(cd "$TMP" && MODERN_EDITOR_DRY=1 "$ROOT/scripts/modern-editor" "dir with space/a b.txt")"
same "start $TMP/dir with space/a b.txt" "$out" "a relative path opens against the working folder"
out="$(MODERN_EDITOR_DRY=1 "$ROOT/scripts/modern-editor" "file://$TMP/dir%20with%20space/a%20b.txt")"
same "start $TMP/dir with space/a b.txt" "$out" "a file:// URI is decoded"
out="$(MODERN_EDITOR_DRY=1 "$ROOT/scripts/modern-editor")"
same "start <new>" "$out" "no argument opens one empty window"
MODERN_EDITOR_ANY_PID=1 "$ROOT/scripts/editor-io.sh" claim "$TMP/dir with space/a b.txt" "$$" >/dev/null
out="$(MODERN_EDITOR_ANY_PID=1 MODERN_EDITOR_DRY=1 "$ROOT/scripts/modern-editor" "$TMP/dir with space/a b.txt")"
same "focus $$ $TMP/dir with space/a b.txt" "$out" "an open file focuses its window"

field() { sed -n "s/^$1=//p" "$DESKTOP" | head -1; }
same "ModernOS Texteditor" "$(field Name)" "desktop entry is ModernOS Texteditor"
same "modern-editor %F" "$(field Exec)" "desktop entry passes files"
same "modern.editor" "$(field StartupWMClass)" "desktop entry matches the window class"
has 'pragma AppId modern.editor' "$QS/editor.qml" "editor.qml sets the app id"
has 'settings.watchFiles: false' "$QS/editor.qml" "a file change never reloads unsaved text away"
mimes="$(field MimeType | tr ';' '\n' | sed '/^$/d' | sort)"
pinned="$(sed -n '/^TEXT_TYPES="/,/"$/p' "$ROOT/scripts/mime-defaults.sh" \
    | sed 's/^TEXT_TYPES=//' | tr -d '"' | tr ' ' '\n' | grep '/' | sort -u)"
missing="$(comm -13 <(printf '%s\n' "$mimes") <(printf '%s\n' "$pinned"))"
same "" "$missing" "every pinned text type is in the desktop entry"
has '"modern.editor": *{ *nameKey: "editor.launcherName"' "$QS/Commons/ModernApps.qml" "the launcher shows the short name"
[ "$(printf '%s\n' "$pinned" | wc -l)" -gt 20 ] || err "TEXT_TYPES could not be read from mime-defaults.sh"

size="$(sed -n 's/.*name = "modern-editor".*size = { \([0-9]*\), \([0-9]*\) }.*/\1 \2/p' \
    "$ROOT/stow/hypr/.config/hypr/modules/windows.lua")"
xxl="$(sed -n 's/.*readonly property real xxl: \([0-9]*\).*/\1/p' "$QS/Commons/Tokens.qml" | head -1)"
w="$(sed -n 's/.*editorWidth: root.spacing.xxl \* \([0-9]*\).*/\1/p' "$QS/Commons/Tokens.qml")"
h="$(sed -n 's/.*editorHeight: root.spacing.xxl \* \([0-9]*\).*/\1/p' "$QS/Commons/Tokens.qml")"
same "$((xxl * w)) $((xxl * h))" "$size" "window rule size matches the tokens"

for lang in en de; do
    file="$ROOT/stow/modern/.config/modern/translations/$lang.json"
    while read -r id key; do
        [ "$(jq -r --arg k "$key" 'getpath($k | split(".")) // empty' "$file")" != "" ] \
            || err "$lang.json lacks $key"
        case "$id" in
            eol:*) ;;
            *) grep -qE "case \"$id\": [A-Za-z]" "$ED/Actions.qml" || err "Actions.run has no case for $id" ;;
        esac
    done < <(sed -n 's/.*{ id: "\([^"]*\)", key: "\([^"]*\)".*/\1 \2/p' "$ED/actions.js")
done
[ "$FAIL" = 0 ] && ok "every command has a label in both languages and a handler"

if command -v node >/dev/null 2>&1; then
    {
        grep -v '^\.pragma' "$ED/textops.js"
        cat <<'JS'
const assert = (c, m) => { if (!c) { console.error("FAIL " + m); process.exitCode = 1; } };
assert(JSON.stringify(find("a.b a.b", "a.b", 1, true, true, true)) === '{"start":4,"end":7}', "find is literal and moves on");
assert(JSON.stringify(find("Ab ab", "AB", 0, true, false, true)) === '{"start":0,"end":2}', "find ignores case when asked");
assert(find("Ab", "ab", 0, true, true, true) === null, "match case is honoured");
assert(JSON.stringify(find("x y x", "x", 0, false, true, true)) === '{"start":4,"end":5}', "backward search wraps");
assert(find("x y", "x", 1, true, true, false) === null, "no wrap stops at the end");
const r = replaceAll("$1 $1", "$1", "$&", true);
assert(r.text === "$& $&" && r.count === 2, "replace all inserts the replacement literally");
assert(count("aaaa", "aa", true) === 2, "matches do not overlap");
const lc = lineCol("ab\ncd", 4);
assert(lc.line === 2 && lc.column === 2, "line and column are 1-based");
assert(lineCount("a\nb\n") === 3 && lineStart("a\nbb\nc", 3) === 5, "line helpers agree");
JS
    } >"$TMP/textops.js"
    if node "$TMP/textops.js"; then ok "text search and replace helpers"; else err "textops"; fi
else
    ok "node not installed; textops checks skipped"
fi

[ "$FAIL" = 0 ] || exit 1
