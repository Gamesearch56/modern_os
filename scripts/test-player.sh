#!/usr/bin/env bash
# Mediaplayer: file layer (test-player.py), launcher, desktop entry,
# defaults, the gone mpv, command table, and the pure playback math.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS="$ROOT/stow/shell/.config/quickshell/modern"
PL="$QS/Modules/Player"
DESKTOP="$ROOT/stow/xdg/.local/share/applications/modern.mediaplayer.desktop"
FAIL=0
err() { printf 'test-player: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-player: ok %s\n' "$*"; }

same() {
    if [ "$2" = "$1" ]; then ok "$3"; else err "$3 (got: $2)"; fi
}
has() {
    if grep -q "$1" "$2"; then ok "$3"; else err "$3"; fi
}
lacks() {
    if grep -rqE "$1" "$2"; then err "$3"; else ok "$3"; fi
}

python3 "$ROOT/scripts/test-player.py" || FAIL=1

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-player-sh-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/dir with space"

run() { (cd "$TMP" && MODERN_PLAYER_DRY=1 "$ROOT/scripts/modern-mediaplayer" "$@"); }
same "start [\"$TMP/dir with space/a b.mkv\"]" "$(run "dir with space/a b.mkv")" "a relative path opens against the working folder"
same "start [\"$TMP/b[0] #1.mp4\"]" "$(run "file://$TMP/b%5B0%5D%20%231.mp4")" "a file:// URI is decoded"
same "start []" "$(run)" "no argument starts with the chooser"
same "start [\"$TMP/a.mp4\"]" "$(run a.mp4 "" "https://example.org/x.mp4")" "empty and remote arguments are dropped"

field() { sed -n "s/^$1=//p" "$DESKTOP" | head -1; }
same "ModernOS Mediaplayer" "$(field Name)" "desktop entry is ModernOS Mediaplayer"
same "Mediaplayer" "$(field 'GenericName\[de\]')" "the German generic name is Mediaplayer"
same "modern-mediaplayer %F" "$(field Exec)" "desktop entry passes files"
same "modern.mediaplayer" "$(field StartupWMClass)" "desktop entry matches the window class"
same "modern-mediaplayer" "$(field Icon)" "desktop entry uses the system icon"
want="$(cd "$ROOT/scripts/lib" && python3 -c 'import player_formats as f; print(";".join(f.mime_types()) + ";")')"
same "$want" "$(field MimeType)" "desktop entry claims exactly the formats the player plays"
lacks 'mpv|vlc|celluloid' "$DESKTOP" "desktop entry names only this player"

has 'pragma AppId modern.mediaplayer' "$QS/mediaplayer.qml" "mediaplayer.qml sets the app id"
has 'settings.watchFiles: false' "$QS/mediaplayer.qml" "a file change never reloads the window away"
has '"modern.mediaplayer": *{ *nameKey: "player.launcherName"' "$QS/Commons/ModernApps.qml" "the launcher shows the short name"
has '"modern-mediaplayer-symbolic"' "$QS/Commons/SystemIcons.qml" "the player joins the system icon plate"
has 'return \["modern.mediaplayer"' "$QS/Commons/DesktopRoles.qml" "the player is the first video player choice"
has '"videoPlayer": "modern.mediaplayer.desktop"' "$ROOT/stow/modern/.config/modern/config.default.json" "the player is the default video player"
has 'property string videoPlayer: "modern.mediaplayer.desktop"' "$QS/Commons/Config.qml" "Config falls back to the player"
same "modern.mediaplayer.desktop" "$(jq -r '.videoPlayer.desktop' "$ROOT/install/manifests/default-apps.json")" "a fresh install opens videos in the player"
has '^qt6-multimedia-ffmpeg ' "$ROOT/install/manifests/20-theming.txt" "the FFmpeg playback backend is installed"
has 'modern-mediaplayer-no-blur' "$ROOT/stow/hypr/.config/hypr/modules/windowrules.lua" "the opaque player skips blur"
lacks 'modern.mediaplayer|modern-mediaplayer' "$ROOT/stow/hypr/.config/hypr/modules/windows.lua" "the player tiles like any window"

if [ -e "$ROOT/stow/mpv" ]; then err "stow/mpv still ships"; else ok "no mpv dotfiles ship"; fi
lacks '"mpv|mpv ' "$QS/Services/FilePreview.qml" "Quick Look plays video without mpv"
has 'muted: true' "$QS/Modules/FilePreview/VideoWindow.qml" "the video preview starts muted"
has 'loops: MediaPlayer.Infinite' "$QS/Modules/FilePreview/VideoWindow.qml" "the video preview loops"
has 'active: FilePreview.open && FilePreview.kind === "video"' "$QS/Modules/FilePreview/Module.qml" "every preview is a fresh window, so an unmute never carries over"
names="$("$ROOT/scripts/pkg-manifest-names.sh" 2>/dev/null || true)"
if [ -z "$names" ]; then
    err "pkg-manifest-names.sh printed nothing"
elif printf '%s\n' "$names" | grep -qxE 'gedit|mpv|imv'; then
    err "a fresh install still pulls in gedit, mpv or imv"
else
    ok "a fresh install pulls in none of gedit, mpv, imv"
fi

for lang in en de; do
    file="$ROOT/stow/modern/.config/modern/translations/$lang.json"
    while read -r id key; do
        [ "$(jq -r --arg k "$key" 'getpath($k | split(".")) // empty' "$file")" != "" ] \
            || err "$lang.json lacks $key"
        grep -qE "case \"$id\":" "$PL/Actions.qml" || err "Actions.run has no case for $id"
    done < <(sed -n '/keys: \[/s/.*{ id: "\([^"]*\)", key: "\([^"]*\)".*/\1 \2/p' "$PL/actions.js")
    while read -r key; do
        [ "$(jq -r --arg k "$key" 'getpath($k | split(".")) // empty' "$file")" != "" ] \
            || err "$lang.json lacks $key"
    done < <(grep -rhoE '"player\.[A-Za-z0-9_.]+[A-Za-z0-9_]"' "$PL" "$QS/Services/PlayerDoc.qml" | tr -d '"' | sort -u)
    for e in missing directory special empty denied readOnlyFs full badName unsupported tooLarge failed; do
        [ "$(jq -r --arg e "$e" '.player.errors[$e] // empty' "$file")" != "" ] || err "$lang.json lacks player.errors.$e"
    done
done
[ "$FAIL" = 0 ] && ok "every command and message has a label in both languages and a handler"

dupes="$(sed -n 's/.*keys: \[\([^]]*\)\].*/\1/p' "$PL/actions.js" | grep -oE '"[^"]+"' | sort | uniq -d)"
same "" "$dupes" "no key is bound to two commands"

if command -v node >/dev/null 2>&1; then
    {
        grep -v '^\.pragma' "$PL/playops.js"
        cat <<'JS'
const assert = (c, m) => { if (!c) { console.error("FAIL " + m); process.exitCode = 1; } };
assert(clock(0) === "0:00" && clock(65000) === "1:05" && clock(3723000) === "1:02:03", "times read like a player's");
assert(clock(-5) === "0:00" && clock(NaN) === "0:00", "nonsense time is zero");
assert(stepSpeed(1, 1) === 1.25 && stepSpeed(1, -1) === 0.75, "speed steps a quarter");
assert(stepSpeed(4, 1) === 4 && stepSpeed(0.25, -1) === 0.25, "speed is bounded");
assert(stepSpeed(1.1, 1) === 1.25 && stepSpeed(1.1, -1) === 1, "an odd rate snaps to the next step");
assert(speedLabel(1.5) === "1.5" && speedLabel(1) === "1", "speed labels drop zeros");
assert(seekTarget(3000, -5000, 20000) === 0 && seekTarget(18000, 5000, 20000) === 19999, "a seek stays in the file");
assert(seekTarget(1000, 60000, 0) === 61000, "an unknown length only keeps a seek above zero");
assert(Math.abs(frameMs(25) - 40) < 1e-9 && frameMs(0) === frameFallbackMs, "one frame from the frame rate");
assert(gain(1) === 1 && gain(0.5) === 0.125 && gain(2) === 1 && gain(-1) === 0, "volume is cubic and clamped");
assert(percent(0.333) === 33, "volume reads in percent");
assert(trackLabel(" Director ", "German") === "Director" && trackLabel("", "German") === "German", "a track is named by title, then language");
assert(trackLabel("", "und") === "" && trackLabel("", "") === "", "an unnamed track has no label");
assert(cycleTrack(-1, 2, true) === 0 && cycleTrack(1, 2, true) === -1 && cycleTrack(1, 2, false) === 0, "tracks cycle like mpv");
assert(cycleTrack(0, 0, true) === -1, "no tracks stays off");
assert(notches(120, 0) === 1 && notches(0, -48) === -1, "wheel and touchpad agree");
assert(clampZoom(0.5) === 1 && clampZoom(100) === maxZoom && zoomed(1, 1) === 1.25, "zoom stays between fit and the maximum");
assert(anchoredOffset(0, 300, 1, 2) === -300 && anchoredOffset(-300, 300, 2, 1) === 0, "zoom keeps the point under the pointer");
assert(clampOffset(-50, 1, 1000, 100, 900) === 0, "a fitted picture stays centred");
assert(clampOffset(500, 2, 1000, 0, 1000) === 0 && clampOffset(-5000, 2, 1000, 0, 1000) === -1000, "a zoomed picture covers the view");
assert(clampOffset(-200, 2, 1000, 0, 0) === 0, "no picture, no offset");
assert(fileUrl("/a/b #1?.mkv") === "file:///a/b%20%231%3F.mkv" && fileUrl("") === "", "a URL keeps # and ? in the name");
JS
    } >"$TMP/playops.js"
    if node "$TMP/playops.js"; then ok "time, speed, seek, volume, track and zoom helpers"; else err "playops"; fi
    {
        grep -v '^\.pragma' "$PL/actions.js"
        cat <<'JS'
const assert = (c, m) => { if (!c) { console.error("FAIL " + m); process.exitCode = 1; } };
const items = menuItems();
assert(items.length === list.filter(a => a.menu).length, "the menu shows every menu command once");
assert(items.filter(a => a.divider).length >= 2, "menu groups are divided");
assert(bindable().every(a => a.keys.length > 0), "only commands with keys are bound");
assert(byId("playPause").keys[0] === "Space" && byId("faster").keys[0] === "]", "keys follow mpv");
const c = choice("speed:1.5");
assert(c.group === "speed" && c.value === 1.5 && choice("next") === null, "a menu choice carries its value");
const speeds = speedItems([0.5, 1, 2], s => String(s));
assert(speeds[1].key === "player.menu.normal" && speeds[2].params.speed === "2", "the speed menu labels normal");
const subs = trackItems("subtitles", [{ label: "German" }, { label: "" }], true);
assert(subs[0].id === "subtitles:-1" && subs[1].value === "German" && subs[2].params.number === 2, "tracks list with Off first");
assert(trackItems("audio", [{ label: "" }], false).length === 1, "audio has no Off");
JS
    } >"$TMP/actions.js"
    if node "$TMP/actions.js"; then ok "command table"; else err "actions.js"; fi
else
    ok "node not installed; playback math checks skipped"
fi

[ "$FAIL" = 0 ] || exit 1
