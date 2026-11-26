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

vivaldi_log() {
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
    mkdir -p "$dir" 2>/dev/null || return 0
    printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$dir/vivaldi.log" 2>/dev/null || true
}

# A later theme merge can leave its tokens path while a repair waits.
_vivaldi_after_exit() {
    local tokens="${1:-}"
    local lock="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/modern-vivaldi-merge.lock"
    if ! mkdir "$lock" 2>/dev/null; then
        if [ -n "$tokens" ]; then
            printf '%s\n' "$tokens" >"$lock/tokens" 2>/dev/null || true
        fi
        return 0
    fi
    if [ -n "$tokens" ]; then
        printf '%s\n' "$tokens" >"$lock/tokens" || true
    fi
    (
        trap 'rm -rf "$lock"' EXIT
        while vivaldi_is_running; do
            sleep 0.5
        done
        sleep 0.5
        pending=""
        if [ -f "$lock/tokens" ]; then
            pending="$(cat "$lock/tokens" 2>/dev/null || true)"
        fi
        if [ -n "$pending" ] && [ -f "$pending" ]; then
            merge_vivaldi_prefs "$pending" || true
        else
            vivaldi_repair_selected_languages
        fi
    ) </dev/null >/dev/null 2>&1 &
    disown $! 2>/dev/null || true
}

schedule_vivaldi_prefs_merge() {
    local tokens="${1:-}"
    [ -n "$tokens" ] && [ -f "$tokens" ] || return 0
    _vivaldi_after_exit "$tokens"
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
    # A theme write must not leave the broken language list in place.
    vivaldi_repair_selected_languages
    # Chromium drops a pre-seeded profile when this file is missing.
    # theme-apply may already have written Preferences, so this is not
    # limited to a brand-new file.
    : >"$cfg/First Run" || true
}

# An earlier release stored intl.selected_languages as one string.
# Chromium registers that preference as a list, so it refuses the
# whole file: settings cannot be read and nothing is saved. Split the
# tags that are already there. Do not pick a language.
vivaldi_language_list_broken() {
    local cfg prefs
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi"
    [ -d "$cfg" ] || return 1
    shopt -s nullglob
    for prefs in "$cfg"/*/Preferences; do
        if jq -e '.intl.selected_languages | type == "string"' "$prefs" >/dev/null 2>&1; then
            shopt -u nullglob
            return 0
        fi
    done
    shopt -u nullglob
    return 1
}

vivaldi_repair_selected_languages() {
    local cfg prefs tmp repaired=0
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi"
    [ -d "$cfg" ] || return 0
    shopt -s nullglob
    for prefs in "$cfg"/*/Preferences; do
        tmp="$prefs.tmp.$$"
        if ! jq -e '.intl.selected_languages | type == "string"' "$prefs" >/dev/null 2>&1; then
            continue
        fi
        if jq '.intl.selected_languages |= (
                (try fromjson catch null) as $parsed
                | if ($parsed | type) == "array" then $parsed
                  else split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
                  end
            )' "$prefs" >"$tmp"; then
            mv "$tmp" "$prefs"
            chmod 600 "$prefs" 2>/dev/null || true
            repaired=$((repaired + 1))
        else
            rm -f "$tmp"
        fi
    done
    shopt -u nullglob
    if [ "$repaired" -gt 0 ]; then
        vivaldi_log "split a language list stored as one string ($repaired settings file(s))"
    fi
}

# The open browser writes the broken list back on exit. Repair after that.
vivaldi_repair_after_exit() {
    if vivaldi_is_running; then
        vivaldi_language_list_broken || return 0
        vivaldi_log "browser is open; the language list repairs after it exits"
        _vivaldi_after_exit ""
        return 0
    fi
    vivaldi_repair_selected_languages
}

# A live update executes this file. Sourcing it only defines the functions.
[ "${BASH_SOURCE[0]}" != "$0" ] || vivaldi_repair_after_exit
