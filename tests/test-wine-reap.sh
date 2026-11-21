#!/usr/bin/env bash
# wine-reap.sh must SIGKILL only the named Wine service comms.
set -euo pipefail
set +m

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAP="$ROOT/scripts/wine-reap.sh"
UNIT="$ROOT/stow/systemd/.config/systemd/user/modern-wine-reap.service"
AUTO="$ROOT/stow/hypr/.config/hypr/modules/autostart.lua"
FAIL=0
err() { printf 'test-wine-reap: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-wine-reap: ok %s\n' "$*"; }

[ -x "$REAP" ] || err "wine-reap.sh is not executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

uid="$(id -u)"
mkdir -p "$tmp/proc/42" "$tmp/proc/43" "$tmp/proc/7" "$tmp/proc/1"
printf 'winedevice.exe\n' >"$tmp/proc/42/comm"
printf 'qs\n' >"$tmp/proc/43/comm"
printf 'winedevice.exe\n' >"$tmp/proc/7/comm"
printf 'winedevice.exe\n' >"$tmp/proc/1/comm"
printf 'Uid:\t%s\t%s\t%s\t%s\n' "$uid" "$uid" "$uid" "$uid" >"$tmp/proc/42/status"
printf 'Uid:\t%s\t%s\t%s\t%s\n' "$uid" "$uid" "$uid" "$uid" >"$tmp/proc/43/status"
printf 'Uid:\t%s\t%s\t%s\t%s\n' 0 0 0 0 >"$tmp/proc/7/status"
printf 'Uid:\t%s\t%s\t%s\t%s\n' "$uid" "$uid" "$uid" "$uid" >"$tmp/proc/1/status"

got="$(WINE_REAP_DRY=1 WINE_REAP_PROC="$tmp/proc" "$REAP")"
if [ "$got" = "42" ]; then
    ok "dry-run selects only this user's wine service"
else
    err "dry-run selected [$got], want 42"
fi

python3 - <<'PY' &
import ctypes, time
libc = ctypes.CDLL(None, use_errno=True)
name = b"winereaptest"
# PR_SET_NAME = 15. comm is what wine-reap.sh matches.
libc.prctl(15, name, 0, 0, 0)
time.sleep(30)
PY
child=$!
# Let the child reach prctl before the scan.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    comm="$(tr -d '\n' <"/proc/$child/comm" 2>/dev/null || true)"
    [ "$comm" = "winereaptest" ] && break
    sleep 0.05
done
WINE_REAP_NAMES=winereaptest "$REAP" || true
if ! kill -0 "$child" 2>/dev/null; then
    ok "live reap kills the named comm"
else
    kill -KILL "$child" 2>/dev/null || true
    err "named comm still running"
fi
wait "$child" 2>/dev/null || true

if grep -Fq 'After=app.slice' "$UNIT" \
    && grep -Fq 'scripts/wine-reap.sh' "$UNIT" \
    && grep -Fq 'RemainAfterExit=yes' "$UNIT" \
    && grep -Fq 'WantedBy=default.target' "$UNIT" \
    && grep -Fq 'DefaultTimeoutStopSec=10s' \
        "$ROOT/stow/systemd/.config/systemd/user.conf.d/99-modern-stop-timeout.conf" \
    && grep -Fq 'modern-wine-reap.service' "$AUTO"; then
    ok "session exit stops wine before app scopes"
else
    err "unit, timeout, or autostart hook missing"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-wine-reap: ok\n'
