#!/usr/bin/env bash
# stow_package removes links left behind by files dropped from a package,
# and nothing else.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DRY_RUN=0
log_info() { :; }
# shellcheck source=install/lib/ui.sh
. "$ROOT/install/lib/ui.sh"
STOW_DIR="$TMP/stow"
# shellcheck source=install/lib/stow.sh
. "$ROOT/install/lib/stow.sh"

mkdir -p "$STOW_DIR/xdg/.local/share/applications" "$TMP/home/.local/share/applications"
apps="$TMP/home/.local/share/applications"
touch "$STOW_DIR/xdg/.local/share/applications/kept.desktop"
ln -s "$STOW_DIR/xdg/.local/share/applications/kept.desktop" "$apps/kept.desktop"
ln -s "$STOW_DIR/xdg/.local/share/applications/gone.desktop" "$apps/gone.desktop"
ln -s "$TMP/elsewhere/other.desktop" "$apps/other.desktop"

_stow_prune "$STOW_DIR/xdg" "$STOW_DIR/xdg" "$TMP/home"

fail=0
[ -L "$apps/kept.desktop" ] || { echo "test-stow-prune: FAIL live link removed" >&2; fail=1; }
[ ! -L "$apps/gone.desktop" ] || { echo "test-stow-prune: FAIL stale link kept" >&2; fail=1; }
[ -L "$apps/other.desktop" ] || { echo "test-stow-prune: FAIL foreign link removed" >&2; fail=1; }
[ "$fail" -eq 0 ] || exit 1
echo "test-stow-prune: ok"
