#!/usr/bin/env bash
# Release-only: boot the built ISO until Calamares writes modern-ci: calamares
# on the guest serial. Not run from ci-check.sh (needs an ISO + QEMU).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MODERN_ISO_OUT:-$ROOT/iso/out}"
QEMU="$ROOT/scripts/iso-qemu.sh"
SERIAL="$OUT/vm-serial.log"
TIMEOUT_SEC="${MODERN_ISO_SMOKE_TIMEOUT:-720}"
MARKER="modern-ci: calamares"

die() { printf 'test-iso-qemu-smoke: FAIL %s\n' "$*" >&2; exit 1; }
log() { printf 'test-iso-qemu-smoke: %s\n' "$*"; }

[ -x "$QEMU" ] || die "missing $QEMU"
command -v qemu-system-x86_64 >/dev/null 2>&1 || die "qemu-system-x86_64 not on PATH"
command -v qemu-img >/dev/null 2>&1 || die "qemu-img not on PATH"
shopt -s nullglob
isos=("$OUT"/*.iso)
shopt -u nullglob
[ ${#isos[@]} -gt 0 ] || die "no ISO in $OUT"

log "booting ${isos[0]} (timeout ${TIMEOUT_SEC}s)"
"$QEMU" --headless &
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
    if [ -f "$SERIAL" ] && grep -F "$MARKER" "$SERIAL" >/dev/null 2>&1; then
        log "saw $MARKER after ${i}s"
        exit 0
    fi
    if ! kill -0 "$qpid" >/dev/null 2>&1; then
        wait "$qpid" || true
        die "qemu exited before $MARKER (serial follows)"$'\n'"$(tail -n 80 "$SERIAL" 2>/dev/null || true)"
    fi
    sleep 1
    i=$((i + 1))
done
die "timeout waiting for $MARKER"$'\n'"$(tail -n 80 "$SERIAL" 2>/dev/null || true)"
