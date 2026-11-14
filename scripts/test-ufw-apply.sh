#!/usr/bin/env bash
# Enable still runs when a default policy command fails, and the files
# Settings reads are left world-readable. No pkexec, no live /etc/ufw.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/scripts/ufw-apply.sh"
FAIL=0
err() { printf 'test-ufw-apply: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-ufw-apply: ok %s\n' "$*"; }

[ -x "$TOOL" ] || err "ufw-apply.sh must be executable"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-ufw-a-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/etc"
cat >"$TMP/bin/ufw" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$UFW_LOG"
if [ "$1" = "default" ]; then
    exit 1
fi
if [ "${1:-}" = "--force" ] && [ "${2:-}" = "enable" ]; then
    exit "${UFW_ENABLE_RC:-0}"
fi
if [ "${1:-}" = "disable" ]; then
    exit 0
fi
exit 1
EOF
chmod 755 "$TMP/bin/ufw"
printf 'ENABLED=no\n' >"$TMP/etc/ufw.conf"
chmod 600 "$TMP/etc/ufw.conf"

export UFW_APPLY_BIN="$TMP/bin/ufw"
export UFW_APPLY_ETCDIR="$TMP/etc"
export UFW_LOG="$TMP/log"
export UFW_ENABLE_RC=0
: >"$UFW_LOG"

if "$TOOL" enable; then
    ok "enable exits 0 when a default command fails"
else
    err "enable must still turn the firewall on"
fi
mode="$(stat -c '%a' "$TMP/etc/ufw.conf")"
if [ "$mode" = "644" ] && grep -qx -- '--force enable' "$UFW_LOG"; then
    ok "enable runs and the conf stays readable"
else
    err "enable did not publish a readable conf (mode $mode): $(cat "$UFW_LOG")"
fi

export UFW_ENABLE_RC=1
: >"$UFW_LOG"
chmod 600 "$TMP/etc/ufw.conf"
set +e
"$TOOL" enable
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$(stat -c '%a' "$TMP/etc/ufw.conf")" = "644" ]; then
    ok "failed enable keeps the conf readable and reports the failure"
else
    err "failed enable rc=$rc mode=$(stat -c '%a' "$TMP/etc/ufw.conf")"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ufw-apply: all passed\n'
