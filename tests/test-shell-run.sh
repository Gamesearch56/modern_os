#!/usr/bin/env bash
# shell-run.sh restarts a crashed shell, stops on a clean exit, a gone
# compositor or a crash loop. A stub stands in for qs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-shell-run: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-shell-run: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-shell-run-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
RUN="$ROOT/scripts/shell-run.sh"

# The stub exits with the next code from $TMP/codes, one per start.
cat >"$TMP/qs" <<'EOF'
#!/usr/bin/env bash
n="$(cat "$STUB_DIR/n" 2>/dev/null || echo 0)"
n=$((n + 1)); echo "$n" >"$STUB_DIR/n"
code="$(sed -n "${n}p" "$STUB_DIR/codes")"
[ "$code" = hang ] && exec sleep 30
exit "${code:-0}"
EOF
printf '%s\n' '#!/bin/sh' 'exit 0' >"$TMP/alive"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$TMP/dead"
chmod +x "$TMP/qs" "$TMP/alive" "$TMP/dead"

run() {
    rm -f "$TMP/n" "$TMP/state/modern/quickshell.log"
    printf '%s\n' "$@" >"$TMP/codes"
    STUB_DIR="$TMP" XDG_STATE_HOME="$TMP/state" XDG_RUNTIME_DIR="$TMP" \
        XDG_DATA_HOME="$TMP/share" \
        MODERN_SHELL_CMD="$TMP/qs" MODERN_SHELL_ALIVE="${ALIVE:-$TMP/alive}" \
        MODERN_SHELL_RESTART_DELAY=0 MODERN_SHELL_MAX_CRASHES=3 "$RUN"
}
log() { cat "$TMP/state/modern/quickshell.log" 2>/dev/null; }

if run 139 0 && [ "$(cat "$TMP/n")" = 2 ] && log | grep -Fq 'shell exited with 139; restarting'; then
    ok "a crash restarts the shell and logs it"
else
    err "crash restart: n=$(cat "$TMP/n" 2>/dev/null) $(log)"
fi

if run 0 && [ "$(cat "$TMP/n")" = 1 ]; then
    ok "a clean exit is not restarted"
else
    err "clean exit restarted"
fi

rc=0; run 1 1 1 1 1 || rc=$?
if [ "$rc" = 1 ] && [ "$(cat "$TMP/n")" = 3 ] && log | grep -Fq 'not restarting'; then
    ok "a crash loop stops after the limit"
else
    err "crash loop: rc=$rc n=$(cat "$TMP/n" 2>/dev/null) $(log)"
fi

if ALIVE="$TMP/dead" run 139 0 && [ "$(cat "$TMP/n")" = 1 ]; then
    ok "no restart once the compositor is gone"
else
    err "restarted without a compositor"
fi

printf 'hang\n' >"$TMP/codes"; rm -f "$TMP/n"
STUB_DIR="$TMP" XDG_STATE_HOME="$TMP/state" XDG_RUNTIME_DIR="$TMP" \
    XDG_DATA_HOME="$TMP/share" MODERN_SHELL_CMD="$TMP/qs" \
    MODERN_SHELL_ALIVE="$TMP/alive" "$RUN" &
sup=$!
for _ in $(seq 1 50); do [ -s "$TMP/n" ] && break; sleep 0.1; done
second=0
STUB_DIR="$TMP" XDG_RUNTIME_DIR="$TMP" XDG_DATA_HOME="$TMP/share" \
    MODERN_SHELL_CMD="$TMP/qs" "$RUN" || second=$?
kill -TERM "$sup"
wait "$sup" 2>/dev/null || true
if [ "$second" = 0 ] && [ "$(cat "$TMP/n")" = 1 ] && ! pgrep -f "sleep 30" -P "$sup" >/dev/null 2>&1; then
    ok "one supervisor per session; SIGTERM stops it"
else
    err "second supervisor or stop: n=$(cat "$TMP/n")"
fi

mkdir -p "$TMP/state/modern"
head -c 2048 /dev/zero >"$TMP/state/modern/quickshell.log"
printf '0\n' >"$TMP/codes"; rm -f "$TMP/n"
STUB_DIR="$TMP" XDG_STATE_HOME="$TMP/state" XDG_RUNTIME_DIR="$TMP" \
    XDG_DATA_HOME="$TMP/share" MODERN_SHELL_CMD="$TMP/qs" \
    MODERN_SHELL_ALIVE="$TMP/alive" MODERN_SHELL_LOG_CAP=1024 "$RUN"
if [ "$(wc -c <"$TMP/state/modern/quickshell.log.1")" = 2048 ] \
    && [ "$(wc -c <"$TMP/state/modern/quickshell.log" 2>/dev/null || echo 0)" -lt 1024 ]; then
    ok "an oversized shell log moves to quickshell.log.1 at start"
else
    err "shell log not rotated"
fi

for app in editor imageviewer mediaplayer; do
    launcher="$ROOT/scripts/modern-$app"
    # shellcheck disable=SC2016
    if grep -Fq 'lib/app-log.sh' "$launcher" && grep -Fq '>>"$out" 2>&1' "$launcher" \
        && ! grep -Eq 'qs -p "\$config" >/dev/null' "$launcher"; then
        ok "modern-$app keeps the window's own output in its log"
    else
        err "modern-$app must send qs output to its rotating log, not /dev/null"
    fi
done

if grep -Fq 'shell-run.sh' "$ROOT/stow/hypr/.config/hypr/modules/autostart.lua" \
    && grep -Fq 'shell-run.sh' "$ROOT/scripts/reload-ui.sh"; then
    ok "login and UI reload start the shell through shell-run.sh"
else
    err "autostart.lua and reload-ui.sh must use shell-run.sh"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-shell-run: ok\n'
