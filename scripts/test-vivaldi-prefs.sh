#!/usr/bin/env bash
# Seed Vivaldi prefs into a throwaway HOME. No live browser, no PII.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-vivaldi-prefs: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-vivaldi-prefs: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-vivaldi-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-vivaldi-prefs: refusing protected home" >&2; exit 1 ;;
    esac
fi

HOME="$TMP/home"
export HOME
export LANG=C LC_ALL=C
unset XDG_CONFIG_HOME
mkdir -p "$HOME/.config/modern"
cat >"$HOME/.config/modern/tokens.json" <<'EOF'
{"color":{"primary":"#d0bcff","surface":"#141218","onSurface":"#e6e0e9","primaryContainer":"#4f378b"}}
EOF

# shellcheck source=lib/vivaldi-prefs.sh
source "$ROOT/scripts/lib/vivaldi-prefs.sh"

if merge_vivaldi_prefs "$HOME/.config/modern/tokens.json"; then
    ok "seeds Preferences on a fresh HOME"
else
    err "merge_vivaldi_prefs failed on an empty HOME"
fi

prefs="$HOME/.config/vivaldi/Default/Preferences"
state="$HOME/.config/vivaldi/Local State"
css="$HOME/.config/vivaldi/custom_css"

if [ -f "$prefs" ] \
    && [ "$(jq -r '.vivaldi.themes.current' "$prefs")" = modern ] \
    && [ "$(jq -r '.vivaldi.customUiMods' "$prefs")" = true ] \
    && [ "$(jq -r '.vivaldi.appearance.css_ui_mods_directory' "$prefs")" = "$css" ] \
    && [ "$(jq -r '.vivaldi.appearance.disable_title_bar' "$prefs")" = true ] \
    && [ "$(jq -r '.vivaldi.theme.schedule.o_s.dark' "$prefs")" = modern ]; then
    ok "theme id, CSS path, and title-bar flag are set"
else
    err "Preferences missing modern theme or CSS mods path"
fi

if [ -f "$state" ] \
    && jq -e '.browser.enabled_labs_experiments | index("vivaldi-css-mods@1")' "$state" >/dev/null; then
    ok "Local State enables vivaldi-css-mods"
else
    err "Local State missing vivaldi-css-mods@1"
fi

if grep -F '/home/devuser/' "$prefs" >/dev/null 2>&1 \
    || grep -F '/home/devuser/' "$state" >/dev/null 2>&1; then
    err "prefs hardcoded a live username"
else
    ok "paths follow HOME, not a live username"
fi

if jq -e '.vivaldi.vivaldi_account or .vivaldi.bookmarks or .account_id' "$prefs" >/dev/null 2>&1; then
    err "seeded Preferences contains account or bookmark keys"
else
    ok "seed has no account or bookmark keys"
fi

[ "$FAIL" -eq 0 ]
