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
# A real browser must not make this test defer the theme write, and the
# waiter's lock must not be the session lock.
bindir="$TMP/bin"
mkdir -p "$bindir" "$TMP/run" "$HOME/.config/modern"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$bindir/pgrep"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$bindir/systemctl"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$bindir/gsettings"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$bindir/dbus-run-session"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$bindir/gtk-update-icon-cache"
chmod 755 "$bindir"/*
export PATH="$bindir:$PATH"
export XDG_RUNTIME_DIR="$TMP/run"
cat >"$HOME/.config/modern/tokens.json" <<'EOF'
{"mode":"dark","color":{"primary":"#d0bcff","surface":"#141218","onSurface":"#e6e0e9","onPrimary":"#381e72","primaryContainer":"#4f378b"}}
EOF

# shellcheck source=../scripts/lib/vivaldi-prefs.sh
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
    && [ "$(jq -r '.vivaldi.themes.user[] | select(.id=="modern") | .colorAccentBg' "$prefs")" = "#d0bcff" ] \
    && [ "$(jq -r '.vivaldi.customUiMods' "$prefs")" = true ] \
    && [ "$(jq -r '.vivaldi.appearance.css_ui_mods_directory' "$prefs")" = "$css" ] \
    && [ "$(jq -r '.vivaldi.appearance.disable_title_bar' "$prefs")" = true ] \
    && [ "$(jq -r '.vivaldi.theme.schedule.o_s.dark' "$prefs")" = modern ] \
    && [ "$(jq -r '.vivaldi.system.desktop_theme_color' "$prefs")" = dark ] \
    && [ "$(jq -r '.vivaldi.PreferredColorScheme' "$prefs")" = 2 ]; then
    ok "theme id, accent, CSS path, and title-bar flag are set"
else
    err "Preferences missing modern theme or CSS mods path"
fi

if [ -f "$state" ] \
    && jq -e '.browser.enabled_labs_experiments | index("vivaldi-css-mods@1")' "$state" >/dev/null; then
    ok "Local State enables vivaldi-css-mods"
else
    err "Local State missing vivaldi-css-mods@1"
fi

if [ -f "$HOME/.config/vivaldi/First Run" ]; then
    ok "First Run sentinel keeps the seeded theme"
else
    err "merge must write the First Run sentinel"
fi

foreign=$( { grep -oE '/home/[^/"]+' "$prefs" "$state" 2>/dev/null || true; } | grep -vF "$HOME" || true )
if [ -n "$foreign" ]; then
    err "prefs hardcoded a path outside throwaway HOME: $foreign"
elif grep -F "$HOME" "$prefs" >/dev/null; then
    ok "paths follow throwaway HOME"
else
    err "prefs do not contain throwaway HOME"
fi

if jq -e '.vivaldi.vivaldi_account or .vivaldi.bookmarks or .account_id' "$prefs" >/dev/null 2>&1; then
    err "seeded Preferences contains account or bookmark keys"
else
    ok "seed has no account or bookmark keys"
fi

mkdir -p "$css"
printf '/* leftover */\n' >"$css/00-wallust.css"
merge_vivaldi_prefs "$HOME/.config/modern/tokens.json" || true
if [ ! -f "$css/00-wallust.css" ]; then
    ok "removes leftover 00-wallust.css"
else
    err "00-wallust.css must not stay in custom_css"
fi

if grep -Fq -- '--md-font-scale' "$ROOT/scripts/theme-apply.sh" \
    && grep -Fq 'zoom: var(--md-font-scale)' "$ROOT/scripts/theme-apply.sh"; then
    ok "browser interface follows the font size"
else
    err "Vivaldi chrome must scale with typography.scale"
fi

if ! grep -Fq -- '--lang=' "$ROOT/scripts/vivaldi" \
    && ! grep -Fq 'vivaldi_apply_language' "$ROOT/scripts/session-chrome-sync.sh" \
    && ! grep -Fq 'language.ui' "$ROOT/scripts/lib/vivaldi-prefs.sh"; then
    ok "the desktop language is not written into Vivaldi"
else
    err "Vivaldi must keep its own language"
fi

broken="$HOME/.config/vivaldi/Profile 1/Preferences"
mkdir -p "$(dirname "$broken")"
printf '%s\n' '{"intl":{"selected_languages":"de-DE,de,en-US,en"},"homepage":"kept"}' >"$broken"
vivaldi_repair_selected_languages
vivaldi_repair_selected_languages
if [ "$(jq -c '.intl.selected_languages' "$broken")" = '["de-DE","de","en-US","en"]' ] \
    && [ "$(jq -r '.homepage' "$broken")" = kept ]; then
    ok "a string language list is split so the settings file can be read"
else
    err "the string language list was not repaired"
fi
if grep -Fq 'vivaldi_repair_after_exit' "$ROOT/scripts/vivaldi" \
    && grep -Fq 'scripts/lib/vivaldi-prefs.sh' "$ROOT/install/install.sh"; then
    ok "the launcher and a live update repair the language list"
else
    err "the launcher and a live update must repair the language list"
fi

spaced="$HOME/.config/vivaldi/Profile 2/Preferences"
mkdir -p "$(dirname "$spaced")"
printf '%s\n' '{"intl":{"selected_languages":"de-DE, de, en-US"},"homepage":"kept"}' >"$spaced"
vivaldi_repair_selected_languages
if [ "$(jq -c '.intl.selected_languages' "$spaced")" = '["de-DE","de","en-US"]' ] \
    && [ "$(jq -r '.homepage' "$spaced")" = kept ]; then
    ok "spaces around language tags are removed"
else
    err "spaced language tags were not split cleanly"
fi
if grep -Fq 'split a language list stored as one string' \
    "$HOME/.local/state/modern/vivaldi.log"; then
    ok "the repair is logged for the next report"
else
    err "the repair must be logged"
fi

cp "$ROOT/stow/modern/.config/modern/config.default.json" \
    "$HOME/.config/modern/config.default.json"
wp="$TMP/wall.jpg"
printf 'wallpaper-bytes' >"$wp"
printf '%s\n' "$wp" >"$HOME/.local/state/modern/current-wallpaper"
printf '%s\n' '{"intl":{"selected_languages":"de-DE,de"},"homepage":"kept"}' >"$prefs"
if "$ROOT/scripts/theme-apply.sh" --chrome-only >/dev/null; then
    ok "chrome patch runs"
else
    err "theme-apply --chrome-only failed"
fi
css="$HOME/.config/vivaldi/custom_css"
if [ -f "$css/wallpaper" ] && cmp -s "$wp" "$css/wallpaper" \
    && grep -Fq "url('wallpaper')" "$css/01-chrome.css" \
    && grep -Fq -- '--colorAccentBg: var(--md-primary)' "$ROOT/stow/theme/.config/matugen/templates/vivaldi.css.template" \
    && [ "$(jq -r '.vivaldi.themes.user[] | select(.id=="modern") | .colorAccentBg' "$prefs")" = "#d0bcff" ] \
    && [ "$(jq -c '.intl.selected_languages' "$prefs")" = '["de-DE","de"]' ] \
    && [ "$(jq -r '.homepage' "$prefs")" = kept ]; then
    ok "a wallpaper change still sets the Vivaldi color and background"
else
    err "wallpaper change did not update the Vivaldi color and background"
fi

[ "$FAIL" -eq 0 ]
