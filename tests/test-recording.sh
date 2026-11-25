#!/usr/bin/env bash
# Recording stop must reach wf-recorder, and the chrome must leave the dock clickable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-recording: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-recording: ok %s\n' "$*"; }

CAST="$ROOT/scripts/screencast.sh"
BAR="$ROOT/stow/shell/.config/quickshell/modern/Modules/Screenshot/RecordingBar.qml"
KEYS="$ROOT/stow/hypr/.config/hypr/modules/keybinds.lua"
CHROME="$ROOT/stow/shell/.config/quickshell/modern/Modules/Screenshot/RecordingChrome.qml"

d=$(printf '\044')
want_pid="echo \"${d}WF_PID\" > \"${d}PIDFILE\""
old_pid="echo ${d}${d} > \"${d}PIDFILE\""
if grep -Fq "$want_pid" "$CAST" && ! grep -Fq "$old_pid" "$CAST"; then
    ok "stop signals wf-recorder, not the wrapper shell"
else
    err "screencast.pid must be the wf-recorder pid"
fi

if grep -Fq 'WlrKeyboardFocus.None' "$BAR" \
    && grep -Fq '_dockClear' "$BAR" \
    && grep -Fq 'root.chromeOpen ? hint :' "$BAR" \
    && ! grep -Fq 'root.chromeOpen ? hintBand' "$BAR"; then
    ok "recording chrome does not take the keyboard or the dock's clicks"
else
    err "the recording overlay must ignore the keyboard and mask only its own hint"
fi

if grep -Fq 'screenshotFull = true' "$KEYS" \
    && grep -Fq 'screenshotRegion = true' "$KEYS"; then
    ok "screenshot keys still fire while an overlay has the keyboard"
else
    err "screenshot binds must bypass overlay keyboard capture so they can stop a recording"
fi

if grep -Fq 'z: -1' "$CHROME"; then
    ok "the stop card does not cover its own button"
else
    err "RecordingChrome's mouse area must stay behind the stop button"
fi

SHELL="$ROOT/stow/shell/.config/quickshell/modern/shell.qml"
MOD="$ROOT/stow/shell/.config/quickshell/modern/Modules/Screenshot/Module.qml"
if ! grep -Fq 'Recording.stop' "$SHELL" \
    && ! grep -Fq 'ApplicationShortcut' "$MOD" \
    && ! grep -Fq 'sequence: "Escape"' "$BAR"; then
    ok "Super+Q and the other shortcuts keep working during a recording"
else
    err "a recording must not eat close or install its own shortcut"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-recording: all passed\n'
