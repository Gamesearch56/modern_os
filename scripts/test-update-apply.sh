#!/usr/bin/env bash
# Unprivileged checks for update-apply.sh / modern update auth flow.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
err() { printf 'test-update-apply: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-update-apply: ok %s\n' "$*"; }
FAIL=0

SCRIPT="$ROOT/scripts/update-apply.sh"
MODERN="$ROOT/scripts/modern"

[ -x "$SCRIPT" ] || err "update-apply.sh must be executable"
[ -f "$MODERN" ] || err "modern missing"

if grep -F 'update-apply.sh' "$MODERN" >/dev/null \
    && ! grep -E 'priv /usr/bin/snapper.*ModernOS Update' "$MODERN" >/dev/null \
    && ! grep -F 'pkexec /usr/bin/pacman -Syu' "$MODERN" >/dev/null; then
    ok "GUI update uses one pkexec of update-apply.sh"
else
    err "modern update must pkexec update-apply.sh once (not snapper then pacman)"
fi

if grep -F 'pacman -Syu --noconfirm' "$SCRIPT" >/dev/null \
    && grep -F 'ModernOS Update' "$SCRIPT" >/dev/null \
    && grep -Fe '--snapshot' "$SCRIPT" >/dev/null; then
    ok "update-apply runs snapper then pacman"
else
    err "update-apply.sh must snapshot (optional) then pacman -Syu"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-update-apply: ok\n'
