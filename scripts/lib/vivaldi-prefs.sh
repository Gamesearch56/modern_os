#!/usr/bin/env bash
# Seed Vivaldi Preferences + Local State with the MD3 theme and CSS
# mods path. Source from scripts/. No accounts, bookmarks, or sync.
# Skips an existing Preferences file while Vivaldi is running (it
# rewrites that file on quit). A missing file is always created so a
# fresh install is themed before the first launch. Return 2 means the
# native theme was deferred until Vivaldi exits.

vivaldi_is_running() {
    pgrep -x vivaldi >/dev/null 2>&1 || pgrep -x vivaldi-bin >/dev/null 2>&1
}

# Other generators drop files here that load after 00-modern.css and pin
# tab / URL-bar colors. Ours is 00-modern.css + 01-chrome.css only.
scrub_vivaldi_css_leftovers() {
    local css_dir="$1"
    [ -d "$css_dir" ] || return 0
    rm -f "$css_dir/00-wallust.css" "$css_dir/wallust.css"
}

schedule_vivaldi_prefs_merge() {
    local tokens="${1:-}"
    local lock="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/modern-vivaldi-merge.lock"
    [ -n "$tokens" ] && [ -f "$tokens" ] || return 0
    mkdir "$lock" 2>/dev/null || return 0
    (
        trap 'rmdir "$lock" 2>/dev/null || true' EXIT
        while vivaldi_is_running; do
            sleep 0.5
        done
        merge_vivaldi_prefs "$tokens" || true
    ) </dev/null >/dev/null 2>&1 &
    disown $! 2>/dev/null || true
}

merge_vivaldi_prefs() {
    local tokens="${1:-}"
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi"
    local prefs="$cfg/Default/Preferences"
    local state="$cfg/Local State"
    local css_dir="$cfg/custom_css"
    local primary surface on_surface on_primary primary_container
    local existed=0

    [ -n "$tokens" ] && [ -f "$tokens" ] || return 1
    mkdir -p "$cfg/Default" "$css_dir"
    scrub_vivaldi_css_leftovers "$css_dir"
    [ -f "$prefs" ] && existed=1
    [ -f "$prefs" ] || printf '%s\n' '{}' >"$prefs"
    [ -f "$state" ] || printf '%s\n' '{}' >"$state"

    if vivaldi_is_running && [ "$existed" -eq 1 ]; then
        schedule_vivaldi_prefs_merge "$tokens"
        return 2
    fi

    primary="$(jq -r '.color.primary' "$tokens")"
    surface="$(jq -r '.color.surface' "$tokens")"
    on_surface="$(jq -r '.color.onSurface' "$tokens")"
    on_primary="$(jq -r '.color.onPrimary' "$tokens")"
    primary_container="$(jq -r '.color.primaryContainer' "$tokens")"
    mode="$(jq -r '.mode // "dark"' "$tokens")"
    case "$primary" in \#*) ;; *) return 1 ;; esac
    # Vivaldi's own default for the system color is light, so menus and
    # dialogs stay bright until this is set. 2 = dark sites, 1 = light.
    case "$mode" in
        light) ui_scheme="light"; web_scheme=1 ;;
        *) ui_scheme="dark"; web_scheme=2 ;;
    esac

    jq \
        --arg bg "$surface" \
        --arg fg "$on_surface" \
        --arg accent "$primary" \
        --arg accent_fg "$on_primary" \
        --arg highlight "$primary_container" \
        --arg css "$css_dir" \
        --arg ui "$ui_scheme" \
        --argjson web "$web_scheme" \
        '.vivaldi.themes.current = "modern"
         | .vivaldi.themes.user = ((.vivaldi.themes.user // []) | map(select(.id != "modern")))
           + [{id:"modern", name:"modern",
               colorBg:$bg, colorFg:$fg, colorAccentBg:$accent,
               colorAccentFg:$accent_fg, colorHighlightBg:$highlight,
               accentOnWindow:false, accentFromPage:false,
               windowBg:$bg}]
         | .vivaldi.theme.schedule.o_s.dark = "modern"
         | .vivaldi.theme.schedule.o_s.light = "modern"
         | .vivaldi.system.desktop_theme_color = $ui
         | .vivaldi.PreferredColorScheme = $web
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
    # Chromium drops a pre-seeded profile when this file is missing.
    # theme-apply may already have written Preferences, so this is not
    # limited to a brand-new file.
    : >"$cfg/First Run" || true
}
