#!/usr/bin/env bash
# The launch cursor is the theme's watch shape standing in for left_ptr
# and the cursor-shape name "default", and it must not come back if a
# newer launch took over.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUSY="$ROOT/scripts/cursor-busy.sh"
LAUNCH="$ROOT/scripts/modern-launch"
APPS="$ROOT/stow/shell/.config/quickshell/modern/Services/Apps.qml"
RAISE="$ROOT/stow/shell/.config/quickshell/modern/Services/HyprRaise.qml"
FAIL=0
err() { printf 'test-cursor-busy: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-cursor-busy: ok %s\n' "$*"; }

if [[ -x "$BUSY" ]] && grep -Fq 'cursor-busy.sh' "$LAUNCH"; then
    raise_line=$(grep -n 'session-raise.sh' "$LAUNCH" | head -1 | cut -d: -f1)
    arm_after=$(awk -v n="$raise_line" 'NR > n && $0 ~ /arm_busy/ { print NR; exit }' "$LAUNCH")
    if [[ -n "$raise_line" && -n "$arm_after" ]] \
        && awk -v a="$raise_line" -v b="$arm_after" 'NR > a && NR < b && /exit 0/ { found = 1 } END { exit found ? 0 : 1 }' "$LAUNCH"; then
        ok "a raised window does not switch the cursor before the real start"
    else
        err "arm_busy must stay after a successful session-raise"
    fi
else
    err "modern-launch must arm cursor-busy.sh only when it starts a program"
fi

if grep -Fq 'cursor-busy.sh' "$RAISE" \
    && grep -Fq 'cursor-busy.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/Launcher.qml" \
    && grep -Fq 'launch-exec.sh' "$APPS"; then
    ok "shell launches arm the watch cursor"
else
    err "launches must start cursor-busy.sh or launch-exec.sh"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/theme/cursors" "$work/icons" "$work/run"
printf 'ARROW' >"$work/theme/cursors/left_ptr"
printf 'WATCH' >"$work/theme/cursors/left_ptr_watch"
printf 'IBEAM' >"$work/theme/cursors/xterm"
ln -s left_ptr "$work/theme/cursors/arrow"

out=$(MODERN_CURSOR_BUSY_DRY=1 \
    MODERN_CURSOR_THEME=TestTheme \
    MODERN_CURSOR_SIZE=32 \
    MODERN_CURSOR_THEME_DIR="$work/theme" \
    MODERN_CURSOR_ICON_ROOT="$work/icons" \
    MODERN_CURSOR_BUSY_RUNTIME="$work/run" \
    "$BUSY" start)
if [[ "$out" == "setcursor modern-cursor-busy 32" ]] \
    && [[ "$(readlink -f "$work/icons/modern-cursor-busy/cursors/left_ptr")" == "$(readlink -f "$work/theme/cursors/left_ptr_watch")" ]] \
    && [[ "$(readlink -f "$work/icons/modern-cursor-busy/cursors/default")" == "$(readlink -f "$work/theme/cursors/left_ptr_watch")" ]] \
    && [[ "$(readlink -f "$work/icons/modern-cursor-busy/cursors/arrow")" == "$(readlink -f "$work/theme/cursors/left_ptr_watch")" ]] \
    && [[ "$(readlink -f "$work/icons/modern-cursor-busy/cursors/xterm")" == "$(readlink -f "$work/theme/cursors/xterm")" ]] \
    && grep -Fq 'Inherits=TestTheme' "$work/icons/modern-cursor-busy/index.theme"; then
    ok "busy theme keeps every shape except the pointer"
else
    err "busy theme did not retarget left_ptr, default, and arrow: ${out:-empty}"
fi

# No watch shape: leave the pointer alone.
mkdir -p "$work/plain/cursors"
printf 'ARROW' >"$work/plain/cursors/left_ptr"
plain=$(MODERN_CURSOR_BUSY_DRY=1 \
    MODERN_CURSOR_THEME=Plain \
    MODERN_CURSOR_THEME_DIR="$work/plain" \
    MODERN_CURSOR_ICON_ROOT="$work/icons2" \
    MODERN_CURSOR_BUSY_RUNTIME="$work/run2" \
    "$BUSY" start || true)
if [[ -z "$plain" && ! -d "$work/icons2/modern-cursor-busy" ]]; then
    ok "a theme with no watch cursor is left unchanged"
else
    err "missing watch cursor should not install a theme (${plain:-empty})"
fi

serve() {
    local path="$1" payload="$2"
    python3 - "$path" "$payload" <<'PY' &
import os, socket, sys, time
path, payload = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(path), exist_ok=True)
try:
    os.unlink(path)
except FileNotFoundError:
    pass
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.bind(path)
sock.listen(1)
sock.settimeout(3)
try:
    conn, _ = sock.accept()
except socket.timeout:
    raise SystemExit(0)
if payload:
    conn.sendall(payload.encode())
    time.sleep(0.2)
conn.close()
PY
    local n=0
    while [[ "$n" -lt 10 ]]; do
        [[ -S "$path" ]] && return 0
        n=$((n + 1))
        sleep 0.05
    done
    return 1
}

sigdir="$work/hypr/testsig"
sock="$sigdir/.socket2.sock"
mkdir -p "$work/run3"
printf 'TestTheme\n' >"$work/run3/theme"
printf '32\n' >"$work/run3/size"
printf 'samegen\n' >"$work/run3/gen"
printf '0xaabb\n' >"$work/run3/address"
serve "$sock" $'activewindowv2>>aabb\nopenwindow>>ccdd,1,App,Title\n'
opened=$(MODERN_CURSOR_BUSY_DRY=1 \
    MODERN_CURSOR_BUSY_RUNTIME="$work/run3" \
    HYPRLAND_INSTANCE_SIGNATURE=testsig \
    XDG_RUNTIME_DIR="$work" \
    "$BUSY" watch samegen)
if [[ "$opened" == "setcursor TestTheme 32" ]]; then
    ok "a new window puts the arrow back"
else
    err "openwindow should restore the theme, got ${opened:-empty}"
fi
wait || true

mkdir -p "$work/run4"
printf 'TestTheme\n' >"$work/run4/theme"
printf '32\n' >"$work/run4/size"
printf 'other\n' >"$work/run4/gen"
serve "$sock" ""
kept=$(MODERN_CURSOR_BUSY_DRY=1 \
    MODERN_CURSOR_BUSY_RUNTIME="$work/run4" \
    HYPRLAND_INSTANCE_SIGNATURE=testsig \
    XDG_RUNTIME_DIR="$work" \
    "$BUSY" watch mine || true)
if [[ -z "$kept" ]]; then
    ok "an older wait does not restore over a newer launch"
else
    err "stale watcher restored the cursor: $kept"
fi
wait || true

mkdir -p "$work/run5"
printf 'TestTheme\n' >"$work/run5/theme"
printf '32\n' >"$work/run5/size"
printf 'samegen\n' >"$work/run5/gen"
serve "$sock" $'activewindowv2>>ffff\n'
focus=$(MODERN_CURSOR_BUSY_DRY=1 \
    MODERN_CURSOR_BUSY_TIMEOUT=0.4 \
    MODERN_CURSOR_BUSY_RUNTIME="$work/run5" \
    HYPRLAND_INSTANCE_SIGNATURE=testsig \
    XDG_RUNTIME_DIR="$work" \
    "$BUSY" watch samegen)
if [[ "$focus" == "setcursor TestTheme 32" ]]; then
    ok "moving focus does not end the loading cursor"
else
    err "a focus change restored the cursor: ${focus:-empty}"
fi

if grep -Fq 'cursorbusy begin' "$BUSY" \
    && grep -Fq 'setOverride' "$ROOT/scripts/hypr-cursor-busy.cpp"; then
    ok "the launch cursor is held above other windows"
else
    err "cursor-busy must hold the watch shape with the hyprland plugin"
fi

if [[ "$FAIL" -ne 0 ]]; then
    exit 1
fi
printf 'test-cursor-busy: ok\n'
