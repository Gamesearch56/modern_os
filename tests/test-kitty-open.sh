#!/usr/bin/env bash
# kitty-open retries only when the first process dies immediately.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-kitty-open: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-kitty-open: ok %s\n' "$*"; }

OPEN="$ROOT/stow/xdg/.local/bin/kitty-open"
DESK="$ROOT/stow/xdg/.local/share/applications/kitty.desktop"
BINDS="$ROOT/stow/hypr/.config/hypr/modules/keybinds.lua"

if [ -x "$OPEN" ] \
    && grep -F 'linux_display_server=x11' "$OPEN" >/dev/null \
    && grep -F 'LIBGL_ALWAYS_SOFTWARE' "$OPEN" >/dev/null \
    && grep -F 'Exec=kitty-open' "$DESK" >/dev/null \
    && grep -F 'kitty-open' "$BINDS" >/dev/null; then
    ok "launcher, Super+T, and Super+Return go through kitty-open"
else
    err "kitty-open must be the desktop Exec and the emergency bind"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls"
cat >"$TMP/kitty" <<'EOF'
#!/usr/bin/env bash
printf 'cache=%s args=%s\n' "${KITTY_CACHE_DIRECTORY-}" "$*" >>"$KITTY_CALLS"
case "${KITTY_MODE:-die}" in
    stay) sleep 30 ;;
    *) exit 1 ;;
esac
EOF
chmod 755 "$TMP/kitty" "$OPEN"

run_open() {
    env -u KITTY_DISABLE_WAYLAND -u LIBGL_ALWAYS_SOFTWARE \
        PATH="$TMP:$PATH" \
        KITTY_CALLS="$LOG" \
        KITTY_OPEN_GRACE=0.2 \
        XDG_STATE_HOME="$TMP/state" \
        "$OPEN"
}

: >"$LOG"
KITTY_MODE=die run_open || true
calls="$(wc -l <"$LOG" | tr -d ' ')"
if [ "$calls" = 3 ] && grep -F -- '--override linux_display_server=x11' "$LOG" >/dev/null; then
    ok "a fast Wayland death retries on XWayland and then software GL"
else
    err "expected 3 kitty attempts, got ${calls:-0}"
fi

: >"$LOG"
KITTY_MODE=stay run_open &
wrap=$!
sleep 0.6
if kill -0 "$wrap" 2>/dev/null; then
    kill "$wrap" 2>/dev/null || true
    wait "$wrap" 2>/dev/null || true
fi
pkill -f "$TMP/kitty" 2>/dev/null || true
calls="$(wc -l <"$LOG" | tr -d ' ')"
if [ "$calls" = 1 ]; then
    ok "a kitty that stays up is not started again"
else
    err "a living kitty was launched ${calls:-0} times"
fi

locked="$TMP/locked-home"
mkdir -p "$locked/.cache"
chmod a-w "$locked/.cache"
: >"$LOG"
HOME="$locked" XDG_CACHE_HOME="$locked/.cache" KITTY_MODE=die run_open || true
chmod u+w "$locked/.cache" || true
if grep -F "cache=$TMP/state/modern/kitty-cache " "$LOG" >/dev/null \
    && [ -d "$TMP/state/modern/kitty-cache" ]; then
    ok "an unwritable ~/.cache uses a private kitty cache"
else
    err "kitty-open did not leave the root-owned cache: $(tr '\n' ' ' <"$LOG")"
fi

if [ "$FAIL" -eq 0 ]; then
    ok "done"
else
    exit 1
fi
