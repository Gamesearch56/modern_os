#!/usr/bin/env bash
# Rewrite the numbered UFW tuple comment. No pkexec, no live /etc/ufw.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/scripts/ufw-comment.sh"
FAIL=0
err() { printf 'test-ufw-comment: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-ufw-comment: ok %s\n' "$*"; }

[ -x "$TOOL" ] || err "ufw-comment.sh must be executable"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-ufw-c-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/ufw"
cat >"$TMP/ufw/user.rules" <<'EOF'
# keep this header
### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in comment=6f6c64
-A ufw-user-input -p tcp --dport 22 -j ACCEPT
### tuple ### allow tcp 80 0.0.0.0/0 any 0.0.0.0/0 in
EOF
cat >"$TMP/ufw/user6.rules" <<'EOF'
### tuple ### allow tcp 443 ::/0 any ::/0 in
EOF
chmod 0644 "$TMP/ufw/user.rules" "$TMP/ufw/user6.rules"

export MODERN_TEST_FIXTURE=1
export UFW_COMMENT_ROOT="$TMP/ufw"

hex() { printf '%s' "$1" | python3 -c 'import sys; print(sys.stdin.read().encode().hex())'; }

"$TOOL" 1 ssh
mode="$(stat -c '%a' "$TMP/ufw/user.rules")"
if grep -Fq "comment=$(hex ssh)" "$TMP/ufw/user.rules" \
    && grep -Fq "# keep this header" "$TMP/ufw/user.rules" \
    && grep -Fq -- "-A ufw-user-input" "$TMP/ufw/user.rules"; then
    ok "sets the first tuple comment and keeps the rest of the file"
else
    err "first tuple rewrite failed"
fi
if [ "$mode" = "644" ]; then
    ok "rewrite keeps the world-readable mode status needs"
else
    err "rewrite changed mode to $mode"
fi

"$TOOL" 2 "web server"
if grep -Fq "comment=$(hex 'web server')" "$TMP/ufw/user.rules"; then
    ok "spaces in a comment stay one field"
else
    err "spaced comment missing"
fi

"$TOOL" 3 https
if grep -Fq "comment=$(hex https)" "$TMP/ufw/user6.rules"; then
    ok "numbering continues into user6.rules"
else
    err "user6 tuple not updated"
fi

"$TOOL" 1
if grep -Fq "### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in" "$TMP/ufw/user.rules" \
    && ! grep -E "tcp 22 .* comment=" "$TMP/ufw/user.rules" >/dev/null; then
    ok "empty comment removes the field"
else
    err "clear comment failed: $(grep 'tcp 22' "$TMP/ufw/user.rules")"
fi

if "$TOOL" 9 ssh >/dev/null 2>&1; then
    err "missing number was accepted"
else
    ok "missing number is rejected"
fi
if "$TOOL" 1 --evil >/dev/null 2>&1; then
    err "leading-dash comment was accepted"
else
    ok "comment cannot start with a dash"
fi
if "$TOOL" 1 'ssh/../x' >/dev/null 2>&1; then
    err "slash in comment was accepted"
else
    ok "comment charset matches Settings"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ufw-comment: all passed\n'
