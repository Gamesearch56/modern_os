#!/usr/bin/env bash
# Local: unattended Calamares in QEMU until late install finishes.
# Not run from ci-check.sh (unpack + m0 takes ~1h).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
QEMU="$ROOT/scripts/iso-qemu.sh"
SERIAL="$OUT/vm-serial.log"
TIMEOUT_SEC="${MODERN_ISO_INSTALL_TIMEOUT:-5400}"
OK="late install finished"
FAIL="calamares-late: ERROR"

die() { printf 'test-iso-qemu-install: FAIL %s\n' "$*" >&2; exit 1; }
log() { printf 'test-iso-qemu-install: %s\n' "$*"; }

[ -x "$QEMU" ] || die "missing $QEMU"
command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 not on PATH"
shopt -s nullglob
isos=("$OUT"/*.iso)
shopt -u nullglob
[ ${#isos[@]} -gt 0 ] || die "no ISO in $OUT"

log "unattended install (timeout ${TIMEOUT_SEC}s)"
"$QEMU" --headless --reset-disk --unattended &
qpid=$!
# trap EXIT below.
# shellcheck disable=SC2329
cleanup() {
    if kill -0 "$qpid" >/dev/null 2>&1; then
        kill "$qpid" >/dev/null 2>&1 || true
        wait "$qpid" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

i=0
while [ "$i" -lt "$TIMEOUT_SEC" ]; do
    if [ -f "$SERIAL" ]; then
        if grep -F "$OK" "$SERIAL" >/dev/null 2>&1; then
            log "saw $OK after ${i}s"
            exit 0
        fi
        if grep -F "$FAIL" "$SERIAL" >/dev/null 2>&1; then
            die "late install error after ${i}s"$'\n'"$(tail -n 80 "$SERIAL" 2>/dev/null || true)"
        fi
    fi
    if ! kill -0 "$qpid" >/dev/null 2>&1; then
        wait "$qpid" || true
        die "qemu exited before $OK (serial follows)"$'\n'"$(tail -n 80 "$SERIAL" 2>/dev/null || true)"
    fi
    sleep 1
    i=$((i + 1))
done
die "timeout waiting for $OK"$'\n'"$(tail -n 80 "$SERIAL" 2>/dev/null || true)"
