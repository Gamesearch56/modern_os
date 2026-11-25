#!/usr/bin/env bash
# report-to-issue.sh keeps Steps, Environment and Device; logs,
# screenshots and the bundle link never reach the public draft.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-report-to-issue: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-report-to-issue: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/report.md" <<'EOF'
## Steps

The bar disappears after resume.

## Environment

- **ModernOS:** `v0.7.7`

## Device

- **GPU:** `AMD Radeon RX 7800 XT (amdgpu)`

## Screenshots

![DP-1](https://example.invalid/shot.jpg?raw=true)

## Logs

<details><summary>quickshell.log</summary>secret-looking log line</details>

## Bundle

[bundle.tar.gz](https://example.invalid/bundle.tar.gz)
EOF

out="$("$ROOT/scripts/report-to-issue.sh" 3 --from "$TMP/report.md")"
for want in "## Steps" "The bar disappears after resume." "## Environment" "v0.7.7" "## Device" "RX 7800 XT"; do
    case "$out" in *"$want"*) ok "keeps $want" ;; *) err "lost $want" ;; esac
done
for gone in "## Screenshots" "shot.jpg" "## Logs" "secret-looking" "## Bundle" "bundle.tar.gz"; do
    case "$out" in *"$gone"*) err "leaks $gone" ;; *) ok "drops $gone" ;; esac
done

exit "$FAIL"
