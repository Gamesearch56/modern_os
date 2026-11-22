#!/usr/bin/env bash
# The palette waits for the wallpaper transition. wallpaper-show writes
# the start line only after the crop, and the shell blends until then.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-wallpaper-color-sync: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-wallpaper-color-sync: ok %s\n' "$*"; }

SHOW="$ROOT/scripts/wallpaper-show.sh"
WALL="$ROOT/stow/shell/.config/quickshell/modern/Services/Wallpaper.qml"
COLORS="$ROOT/stow/shell/.config/quickshell/modern/Commons/Colors.qml"

if grep -Fq 'Colors.armForWallpaper()' "$WALL" \
    && grep -Fq 'Colors.transitionGen' "$WALL" \
    && awk '
        /Colors.armForWallpaper\(\)/ { armed = NR }
        /wallpaper-show\.sh/ && armed && !shown { shown = NR }
        END { exit !(armed && shown && armed < shown) }
    ' "$WALL"; then
    ok "the shell holds colors before the wallpaper script starts"
else
    err "setWallpaper must arm the palette before wallpaper-show"
fi

if grep -Fq 'wait_for_wallpaper_transition' "$ROOT/scripts/theme-apply.sh"; then
    ok "other apps recolor once the wallpaper transition starts"
else
    err "theme-apply must wait for the wallpaper transition before reloading apps"
fi

if grep -Fq 'function armForWallpaper' "$COLORS" \
    && grep -Fq 'blendAnim' "$COLORS" \
    && grep -Fq 'wallpaper-transition' "$COLORS"; then
    ok "colors crossfade across the wallpaper transition"
else
    err "Colors.qml must blend while the wallpaper transition runs"
fi

start_line="$(grep -n 'mark start' "$SHOW" | head -1 | cut -d: -f1)"
awww_line="$(grep -n 'awww img' "$SHOW" | grep SHOW | head -1 | cut -d: -f1)"
prep_line="$(grep -n 'prepare_frame$' "$SHOW" | head -1 | cut -d: -f1)"
if [ -n "$prep_line" ] && [ -n "$start_line" ] && [ -n "$awww_line" ] \
    && [ "$prep_line" -lt "$start_line" ] && [ "$start_line" -lt "$awww_line" ]; then
    ok "the transition is marked after the crop and before awww"
else
    err "wallpaper-show must crop, mark start, then run awww"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/state" "$tmp/img"
printf 'x\n' > "$tmp/img/pic.jpg"

cat > "$tmp/bin/pgrep" <<'EOF'
#!/bin/sh
if [ "$1" = "-x" ] && [ "$2" = "awww-daemon" ]; then
    exit 0
fi
exit 1
EOF
cat > "$tmp/bin/awww" <<'EOF'
#!/bin/sh
mark="${XDG_STATE_HOME:-$HOME/.local/state}/modern/wallpaper-transition"
head -n 1 "$mark" > "${AWWW_LOG:?}"
exit 0
EOF
cat > "$tmp/bin/magick" <<'EOF'
#!/bin/bash
dest=""
for dest; do :; done
touch "$dest"
exit 0
EOF
cat > "$tmp/bin/hyprctl" <<'EOF'
#!/bin/sh
if [ "$1" = "monitors" ]; then
    printf '%s\n' '[{"width":100,"height":50}]'
    exit 0
fi
exit 1
EOF
chmod +x "$tmp/bin/pgrep" "$tmp/bin/awww" "$tmp/bin/magick" "$tmp/bin/hyprctl"

export PATH="$tmp/bin:$PATH"
export XDG_STATE_HOME="$tmp/state"
export AWWW_LOG="$tmp/awww.log"
export HOME="$tmp"
if "$SHOW" "$tmp/img/pic.jpg" fade 7; then
    ok "wallpaper-show ran with a stubbed awww"
else
    err "wallpaper-show failed under stubs"
fi

if [ -f "$tmp/awww.log" ] && grep -q '^start 0.400 7 ' "$tmp/awww.log" \
    && grep -q '^done 0 7 ' "$tmp/state/modern/wallpaper-transition"; then
    ok "awww starts after the transition mark and the run closes with done"
else
    err "expected start before awww and done afterwards"
    printf 'test-wallpaper-color-sync: awww log:\n' >&2
    cat "$tmp/awww.log" >&2 || true
    printf 'test-wallpaper-color-sync: mark:\n' >&2
    cat "$tmp/state/modern/wallpaper-transition" >&2 || true
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-wallpaper-color-sync: ok\n'
