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
    if [ -n "$tokens" ] && [ ! -f "$tokens" ]; then
        tokens=""
    fi
    mkdir "$lock" 2>/dev/null || return 0
    (
        trap 'rmdir "$lock" 2>/dev/null || true' EXIT
        while vivaldi_is_running; do
            sleep 0.5
        done
        if [ -n "$tokens" ]; then
            merge_vivaldi_prefs "$tokens" || true
        else
            vivaldi_apply_language_now || true
        fi
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
    # The desktop language is the browser language. A theme refresh
    # must not leave Vivaldi on the language it shipped with.
    vivaldi_apply_language_now
    # Chromium drops a pre-seeded profile when this file is missing.
    # theme-apply may already have written Preferences, so this is not
    # limited to a brand-new file.
    : >"$cfg/First Run" || true
}

# Chromium's UI pak is "de" or "en-US", not the glibc locale.
vivaldi_ui_locale() {
    local id="$1" country="$2"
    case "$id" in
        en)
            case "$country" in
                GB|IE) printf 'en-GB\n' ;;
                *) printf 'en-US\n' ;;
            esac
            ;;
        pt)
            case "$country" in
                PT) printf 'pt-PT\n' ;;
                *) printf 'pt-BR\n' ;;
            esac
            ;;
        zh)
            case "$country" in
                TW) printf 'zh-TW\n' ;;
                HK) printf 'zh-HK\n' ;;
                *) printf 'zh-CN\n' ;;
            esac
            ;;
        *) printf '%s\n' "$id" ;;
    esac
}

# Three lines: UI locale, Accept-Language list, spellcheck dictionary.
vivaldi_language_fields() {
    local cfg langs id country locale region accept
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
    langs="${XDG_CONFIG_HOME:-$HOME/.config}/modern/languages.json"
    id="en"
    if [ -f "$cfg" ]; then
        id="$(jq -r '.language.ui // "en"' "$cfg" 2>/dev/null || printf 'en')"
    fi
    id="${id//[!a-z]/}"
    [ -n "$id" ] || id="en"
    country=""
    if [ -f "$langs" ]; then
        country="$(jq -r --arg id "$id" '
            .languages[] | select(.id == $id) | .country // empty
        ' "$langs" 2>/dev/null | head -n 1 || true)"
    fi
    case "$country" in
        [A-Z][A-Z]) ;;
        *) country="" ;;
    esac
    locale="$(vivaldi_ui_locale "$id" "$country")"
    region=""
    if [ -n "$country" ]; then
        region="${id}-${country}"
    fi
    if [ "$locale" = "en-US" ]; then
        accept="en-US,en"
    else
        accept="$locale"
        if [ -n "$region" ] && [ "$region" != "$locale" ]; then
            accept="${region},${accept}"
        fi
        accept="${accept},en-US,en"
    fi
    printf '%s\n%s\n%s\n' "$locale" "$accept" "$locale"
}

vivaldi_apply_language_now() {
    local cfg locale accept spell prefs state tmp
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi"
    {
        IFS= read -r locale
        IFS= read -r accept
        IFS= read -r spell
    } < <(vivaldi_language_fields)
    [ -n "$locale" ] && [ -n "$accept" ] || return 1
    mkdir -p "$cfg/Default"
    [ -f "$cfg/Default/Preferences" ] || printf '%s\n' '{}' >"$cfg/Default/Preferences"
    state="$cfg/Local State"
    [ -f "$state" ] || printf '%s\n' '{}' >"$state"
    shopt -s nullglob
    for prefs in "$cfg"/*/Preferences; do
        tmp="$prefs.tmp.$$"
        # selected_languages is a list. A comma-separated string is the
        # accept_languages type, and Vivaldi then refuses the whole file:
        # settings cannot be read and nothing the user changes is saved.
        if jq --arg accept "$accept" --arg spell "$spell" '
            .intl.accept_languages = $accept
            | .intl.selected_languages = ($accept | split(","))
            | .spellcheck.dictionaries = [$spell]
        ' "$prefs" >"$tmp"; then
            mv "$tmp" "$prefs"
            chmod 600 "$prefs" 2>/dev/null || true
        else
            rm -f "$tmp"
            shopt -u nullglob
            return 1
        fi
    done
    shopt -u nullglob
    tmp="$state.tmp.$$"
    if jq --arg locale "$locale" '.intl.app_locale = $locale' "$state" >"$tmp"; then
        mv "$tmp" "$state"
        chmod 600 "$state" 2>/dev/null || true
    else
        rm -f "$tmp"
        return 1
    fi
}

# Vivaldi rewrites Preferences on quit. A live browser keeps the write
# until that exit; the next start also receives --lang from scripts/vivaldi.
vivaldi_apply_language() {
    local tokens="${XDG_CONFIG_HOME:-$HOME/.config}/modern/tokens.json"
    if vivaldi_is_running && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi/Default/Preferences" ]; then
        if [ -f "$tokens" ]; then
            schedule_vivaldi_prefs_merge "$tokens"
        else
            schedule_vivaldi_prefs_merge ""
        fi
        return 2
    fi
    vivaldi_apply_language_now
}
