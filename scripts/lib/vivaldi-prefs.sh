#!/usr/bin/env bash
# Seed Vivaldi Preferences + Local State with the MD3 theme and CSS
# mods path. Source from scripts/. No accounts, bookmarks, or sync.
# Skips an existing Preferences file while Vivaldi is running (it
# rewrites that file on quit). A missing file is always created so a
# fresh install is themed before the first launch.

merge_vivaldi_prefs() {
    local tokens="${1:-}"
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi"
    local prefs="$cfg/Default/Preferences"
    local state="$cfg/Local State"
    local css_dir="$cfg/custom_css"
    local primary surface on_surface primary_container
    local existed=0 running=0

    [ -n "$tokens" ] && [ -f "$tokens" ] || return 1
    mkdir -p "$cfg/Default" "$css_dir"
    [ -f "$prefs" ] && existed=1
    [ -f "$prefs" ] || printf '%s\n' '{}' >"$prefs"
    [ -f "$state" ] || printf '%s\n' '{}' >"$state"

    if pgrep -x vivaldi >/dev/null 2>&1 || pgrep -x vivaldi-bin >/dev/null 2>&1; then
        running=1
    fi
    if [ "$running" -eq 1 ] && [ "$existed" -eq 1 ]; then
        return 1
    fi

    primary="$(jq -r '.color.primary' "$tokens")"
    surface="$(jq -r '.color.surface' "$tokens")"
    on_surface="$(jq -r '.color.onSurface' "$tokens")"
    primary_container="$(jq -r '.color.primaryContainer' "$tokens")"
    case "$primary" in \#*) ;; *) return 1 ;; esac

    jq \
        --arg bg "$surface" \
        --arg fg "$on_surface" \
        --arg accent "$primary" \
        --arg highlight "$primary_container" \
        --arg css "$css_dir" \
        '.vivaldi.themes.current = "modern"
         | .vivaldi.themes.user = ((.vivaldi.themes.user // []) | map(select(.id != "modern")))
           + [{id:"modern", name:"modern",
               colorBg:$bg, colorFg:$fg, colorAccentBg:$accent,
               colorHighlightBg:$highlight,
               accentOnWindow:false, accentFromPage:false,
               windowBg:$bg}]
         | .vivaldi.theme.schedule.o_s.dark = "modern"
         | .vivaldi.theme.schedule.o_s.light = "modern"
         | .vivaldi.customUiMods = true
         | .vivaldi.appearance.css_ui_mods_directory = $css
         | .vivaldi.appearance.disable_title_bar = true' \
        "$prefs" >"$prefs.tmp" && mv "$prefs.tmp" "$prefs"
    chmod 600 "$prefs" 2>/dev/null || true

    jq '
        .browser.enabled_labs_experiments = (
            (.browser.enabled_labs_experiments // [])
            | if index("vivaldi-css-mods@1") then . else . + ["vivaldi-css-mods@1"] end
        )
    ' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
    chmod 600 "$state" 2>/dev/null || true
}
