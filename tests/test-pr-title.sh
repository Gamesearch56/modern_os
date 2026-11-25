#!/usr/bin/env bash
# check-pr-title.sh accepts what release-notes.sh can sort, rejects the rest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-pr-title.sh"
FAIL=0
err() { printf 'test-pr-title: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pr-title: ok %s\n' "$*"; }

for t in \
    "fix(audio): keep the headset profile after resume" \
    "feat: calculator provider" \
    "feat(config)!: settings live in config.json only" \
    "remove(bar): the legacy clock widget" \
    "ci: split lint from tests" \
    "Release v0.8.0" \
    'Revert "feat: calculator provider"'; do
    if "$CHECK" "$t" 2>/dev/null; then ok "accepts: $t"; else err "rejects: $t"; fi
done

for t in \
    "" \
    "Fix the headset profile" \
    "feature: calculator" \
    "fix:no space" \
    "fix(Audio): uppercase scope" \
    "fix: ends with a full stop." \
    "fix: $(printf 'x%.0s' {1..80})" \
    "Release 0.8.0"; do
    if "$CHECK" "$t" 2>/dev/null; then err "accepts: $t"; else ok "rejects: ${t:0:40}"; fi
done

exit "$FAIL"
