#!/usr/bin/env bash
# Same gates as .github/workflows/ci.yml `checks` (minus the Arch
# install-dry job). Run before commit and push. Exits non-zero on the
# first failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# User-local install (no sudo) so hooks see shellcheck on this clone.
PATH="${HOME}/.local/bin:${PATH}"

die() { printf 'ci-check: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'ci-check: %s\n' "$*"; }

need=(jq python3 git shellcheck)
missing=()
for cmd in "${need[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done
if [ ${#missing[@]} -gt 0 ]; then
    die "missing ${missing[*]} (CI installs: jq python3 shellcheck git)"
fi
log "dependencies ok (${need[*]})"

log "layer lint"
"$ROOT/scripts/lint-layers.sh"

log "shellcheck"
mapfile -t files < <(git ls-files '*.sh' | grep -E '^(install/|scripts/|iso/airootfs/)')
[ ${#files[@]} -gt 0 ] || die "no shell scripts matched CI's git ls-files filter"
shellcheck "${files[@]}"
log "shellcheck ok (${#files[@]} files)"

log "settings catalog"
"$ROOT/scripts/test-settings-catalog.sh"
log "desktop-sync"
"$ROOT/scripts/test-desktop-sync.sh"
log "nautilus prefs"
"$ROOT/scripts/test-nautilus-prefs.sh"
log "vivaldi prefs"
"$ROOT/scripts/test-vivaldi-prefs.sh"
log "iso package list"
"$ROOT/scripts/test-iso-package-list.sh"
log "iso live kiosk"
"$ROOT/scripts/test-iso-live-kiosk.sh"
log "calamares late"
"$ROOT/scripts/test-calamares-late.sh"
log "calamares patches"
"$ROOT/scripts/test-calamares-patches.sh"
log "release notes"
"$ROOT/scripts/test-release-notes.sh"
log "autologin apply"
"$ROOT/scripts/test-autologin-apply.sh"

log "ok"
