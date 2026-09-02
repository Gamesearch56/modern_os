#!/usr/bin/env bash
# nautilus-prefs.sh --bookmarks-only. No gsettings / no live home.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-nautilus-prefs: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-nautilus-prefs: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-nautilus-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-nautilus-prefs: refusing protected home" >&2; exit 1 ;;
    esac
fi

HOME="$TMP/home"
export HOME
export LANG=C LC_ALL=C
unset XDG_CONFIG_HOME XDG_DATA_HOME
mkdir -p "$HOME"

if ! "$ROOT/scripts/nautilus-prefs.sh" --bookmarks-only; then
    err "nautilus-prefs.sh --bookmarks-only failed"
else
    ok "bookmarks-only exits 0"
fi

got="$HOME/.config/gtk-3.0/bookmarks"
if [ -f "$got" ] \
    && grep -F "file://$HOME/Downloads Downloads" "$got" >/dev/null \
    && grep -F "file://$HOME/Pictures Pictures" "$got" >/dev/null \
    && grep -F "file://$HOME/Videos Videos" "$got" >/dev/null \
    && ! grep -F '/home/devuser/' "$got" >/dev/null; then
    ok "seeds Downloads Pictures Videos for the target HOME"
else
    err "bookmarks were '$(cat "$got" 2>/dev/null || echo missing)'"
fi

printf 'file://%s/keep Keep\n' "$HOME" >"$got"
"$ROOT/scripts/nautilus-prefs.sh" --bookmarks-only
if grep -F "file://$HOME/keep Keep" "$got" >/dev/null \
    && ! grep -F Downloads "$got" >/dev/null; then
    ok "does not overwrite an existing bookmarks file"
else
    err "re-run replaced user bookmarks"
fi

if grep -F 'xdg-user-dir' "$ROOT/scripts/nautilus-prefs.sh" >/dev/null \
    && grep -F 'DOWNLOAD PICTURES VIDEOS' "$ROOT/scripts/nautilus-prefs.sh" >/dev/null \
    && grep -F 'bookmarks' "$ROOT/stow/gtk/.stow-local-ignore" >/dev/null; then
    ok "stow will not ship a hardcoded bookmarks file"
else
    err "nautilus-prefs / stow-local-ignore missing the XDG seed"
fi

[ "$FAIL" -eq 0 ]
