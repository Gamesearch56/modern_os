#!/usr/bin/env bash
# aur_pkg_present: exact name or source name for a requested *-bin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-pkg-aur: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-pkg-aur: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-pkg-aur-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

cat >"$TMP/pacman" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-Qq" ]; then
    case "${2:-}" in
        matugen|bibata-cursor-theme) exit 0 ;;
        *) exit 1 ;;
    esac
fi
exit 1
EOF
chmod +x "$TMP/pacman"

export PATH="$TMP:$PATH"
export REPO_ROOT="$ROOT"
export LOG_FILE="$TMP/install.log"
export DRY_RUN=0 ASSUME_YES=1
# shellcheck source=../install/lib/log.sh
source "$ROOT/install/lib/log.sh"
# shellcheck source=../install/lib/ui.sh
source "$ROOT/install/lib/ui.sh"
# shellcheck source=../install/lib/pkg.sh
source "$ROOT/install/lib/pkg.sh"

if aur_pkg_present matugen-bin && aur_pkg_present bibata-cursor-theme-bin \
    && aur_pkg_present matugen && ! aur_pkg_present phylax-git; then
    ok "source names satisfy matching -bin requests"
else
    err "aur_pkg_present missed source/bin pairs"
fi

[ "$FAIL" -eq 0 ]
