#!/usr/bin/env bash
# Regenerates every theme output file (tokens.json, Colors.qml, kitty
# colors, Hyprland border colors, plus the GTK/Qt/KDE/Vivaldi templates —
# see stow/theme/.config/matugen/config.toml) from the active theme
# profile, then reloads the apps that can pick the change up live.
#
# tokens.json is the single source of truth: everything else in this
# list is generated from the same matugen run, so nothing can drift out
# of sync the way the old Wallust templates could.
#
# Usage:
#   theme-apply.sh [--profile NAME] [--wallpaper PATH] [--no-reload]
#
#   --profile NAME     One of stow/modern/.config/modern/themes/*.json,
#                       by filename without ".json"
#                       (default: config.json's design.activeProfile).
#   --wallpaper PATH   Absolute path to an image. Required the first
#                       time a "sourceMode": "wallpaper" profile is
#                       applied; remembered afterwards in
#                       $STATE_DIR/current-wallpaper. Also sets the
#                       wallpaper itself via awww, with a transition.
#   --no-reload        Regenerate files only, skip live-reload side
#                       effects (used by CI/lint and the M0 verify
#                       script, where no Hyprland session is running).
#
# See docs/THEMING.md for the full pipeline and docs/ARCHITECTURE.md's
# "colors" data flow for why tokens.json/config.json are two separate,
# independently-writable files.
set -euo pipefail

MODERN_DIR="$HOME/.config/modern"
THEMES_DIR="$MODERN_DIR/themes"
# Runtime state (not config, not tracked in git) — see docs/ARCHITECTURE.md
# "Where things run". Distinct from scripts/check-isolation.sh's own
# $XDG_STATE_HOME/modern-dotfile, which tracks this repo's *development*
# isolation, not the live system's state.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
WALLPAPER_STATE="$STATE_DIR/current-wallpaper"
LAST_APPLIED_STATE="$STATE_DIR/theme-last-applied.json"
MATUGEN_CONFIG="$HOME/.config/matugen/config.toml"

log()  { printf '\033[36m[theme-apply]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[theme-apply] WARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[theme-apply] ERROR\033[0m %s\n' "$*" >&2; exit 1; }

# Merge an MD3 theme object into Vivaldi's Preferences. Skipped when
# Vivaldi is running — it rewrites that file on quit and would clobber
# us (the CSS overlay still applies either way).
merge_vivaldi_theme() {
    local prefs="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi/Default/Preferences"
    local tokens="$MODERN_DIR/tokens.json"
    [ -f "$prefs" ] || return 0
    [ -f "$tokens" ] || return 0
    if pgrep -x vivaldi >/dev/null 2>&1 || pgrep -x vivaldi-bin >/dev/null 2>&1; then
        warn "Vivaldi is running — not touching Preferences; CSS overlay is already updated"
        return 0
    fi
    local primary surface on_surface primary_container
    primary="$(jq -r '.color.primary' "$tokens")"
    surface="$(jq -r '.color.surface' "$tokens")"
    on_surface="$(jq -r '.color.onSurface' "$tokens")"
    primary_container="$(jq -r '.color.primaryContainer' "$tokens")"
    local radius
    radius="$(merged_config | jq -r '.design.cornerRounding // 1')"
    jq \
        --arg bg "$surface" \
        --arg fg "$on_surface" \
        --arg accent "$primary" \
        --arg highlight "$primary_container" \
        --argjson radius "$radius" \
        '.vivaldi.themes.current = "modern"
         | .vivaldi.themes.user = ((.vivaldi.themes.user // []) | map(select(.id != "modern")))
           + [{id:"modern", name:"modern",
               colorBg:$bg, colorFg:$fg, colorAccentBg:$accent,
               colorHighlightBg:$highlight,
               accentOnWindow:false, accentFromPage:false,
               windowBg:$bg}]
         | .vivaldi.customUiMods = true' \
        "$prefs" > "$prefs.tmp" && mv "$prefs.tmp" "$prefs"
    log "merged Vivaldi native theme (id=modern)"
}

patch_toolkit_chrome() {
    local cfg radius font mono blur trans
    cfg="$(merged_config)"
    radius="$(jq -r '.design.cornerRounding // 1' <<<"$cfg")"
    font="$(jq -r '.typography.ui // "Inter"' <<<"$cfg")"
    mono="$(jq -r '.typography.monospace // "JetBrainsMono Nerd Font"' <<<"$cfg")"
    blur="$(jq -r '.design.blurStrength // 40' <<<"$cfg")"
    trans="$(jq -r '.design.transparency // 0.85' <<<"$cfg")"
    local sm md lg
    sm="$(awk -v r="$radius" 'BEGIN { printf "%.0f", 8*r }')"
    md="$(awk -v r="$radius" 'BEGIN { printf "%.0f", 16*r }')"
    lg="$(awk -v r="$radius" 'BEGIN { printf "%.0f", 28*r }')"
    local css_dir="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi/custom_css"
    mkdir -p "$css_dir"
    local wp_on
    wp_on="$(jq -r '.design.bootScreen.wallpaperOnVivaldi // false' <<<"$cfg")"
    local wp_url="none"
    if [ "$wp_on" = "true" ] && [ -f "$WALLPAPER_STATE" ]; then
        local src
        src="$(cat "$WALLPAPER_STATE")"
        if [ -f "$src" ]; then
            cp -f "$src" "$css_dir/wallpaper"
            wp_url="url('wallpaper')"
        fi
    else
        rm -f "$css_dir/wallpaper"
    fi
    cat > "$css_dir/01-chrome.css" <<EOF
:root {
  --md-font-ui: ${font};
  --md-font-mono: ${mono};
  --md-radius-sm: ${sm}px;
  --md-radius-md: ${md}px;
  --md-radius-lg: ${lg}px;
  --md-radius-full: 9999px;
  --md-space-xs: 4px;
  --md-space-sm: 8px;
  --md-space-md: 12px;
  --md-space-lg: 16px;
  --md-space-xl: 24px;
  --md-blur: ${blur}px;
  --md-transparency: $(awk -v t="$trans" 'BEGIN { printf "%.0f", t*100 }')%;
  --md-wallpaper: ${wp_url};
}
body, #browser { font-family: var(--md-font-ui), sans-serif !important; }
EOF
    local qss="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qss/modern.qss"
    if [ -f "$qss" ]; then
        local tmp
        tmp="$(mktemp)"
        sed \
            -e "s|@FONT_UI@|${font}|g" \
            -e "s|@RADIUS_SM@|${sm}|g" \
            -e "s|@RADIUS_MD@|${md}|g" \
            -e "s|@RADIUS_FULL@|9999|g" \
            -e "s|@SPACE_XS@|4|g" \
            -e "s|@SPACE_SM@|8|g" \
            -e "s|@SPACE_MD@|12|g" \
            "$qss" > "$tmp" && mv "$tmp" "$qss"
    fi
    local kde="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
    if [ -f "$kde" ]; then
        local scale
        scale="$(jq -r '.typography.scale // 1' <<<"$cfg")"
        local pt
        pt="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 11*s }')"
        local icon
        icon="$(jq -r '.design.iconTheme // "Papirus-Dark"' <<<"$cfg")"
        awk -v font="$font" -v mono="$mono" -v pt="$pt" -v icon="$icon" '
            BEGIN { g=0; i=0 }
            /^\[General\]/ { print; print "font=" font "," pt ",-1,5,50,0,0,0,0,0"; print "fixed=" mono "," pt ",-1,5,50,0,0,0,0,0"; g=1; next }
            /^\[Icons\]/ { print; print "Theme=" icon; i=1; next }
            { print }
            END {
              if (!g) { print "[General]"; print "font=" font "," pt ",-1,5,50,0,0,0,0,0" }
              if (!i) { print "[Icons]"; print "Theme=" icon }
            }
        ' "$kde" > "$kde.tmp" && mv "$kde.tmp" "$kde"
    fi
    local qtconf="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"
    if [ -f "$qtconf" ]; then
        local icon
        icon="$(jq -r '.design.iconTheme // "Papirus-Dark"' <<<"$cfg")"
        awk -v icon="$icon" '
            /^icon_theme=/ { print "icon_theme=" icon; next }
            /^stylesheets=/ { print "stylesheets=~/.config/qt6ct/qss/modern.qss"; next }
            { print }
        ' "$qtconf" > "$qtconf.tmp" && mv "$qtconf.tmp" "$qtconf"
        if ! grep -q '^stylesheets=' "$qtconf"; then
            printf '\n[Interface]\nstylesheets=~/.config/qt6ct/qss/modern.qss\n' >> "$qtconf"
        fi
    fi

    # hyprpolkitagent (and other hypr* Qt Quick apps) read chrome from
    # ~/.config/hypr/application-style.conf — QSS never reaches that QML
    # style. Enum steps are 0/4/8/16 px; Tokens.radius.small is 8 * rounding.
    local hypr_round=2
    if [ "$sm" -le 2 ]; then
        hypr_round=0
    elif [ "$sm" -le 6 ]; then
        hypr_round=1
    elif [ "$sm" -le 12 ]; then
        hypr_round=2
    else
        hypr_round=3
    fi
    local motion_scale reduce_motion
    motion_scale="$(jq -r '.motion.scale // 1' <<<"$cfg")"
    if awk -v s="$motion_scale" 'BEGIN { exit (s+0 == 0) ? 0 : 1 }'; then
        reduce_motion="true"
    else
        reduce_motion="false"
    fi
    local style_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/application-style.conf"
    mkdir -p "$(dirname "$style_conf")"
    cat > "$style_conf" <<EOF
# GENERATED by scripts/theme-apply.sh — do not hand-edit.
# Maps config.json design.cornerRounding / motion.scale onto
# hyprland-qt-support (hyprpolkitagent QML chrome). See docs/THEMING.md.
roundness = ${hypr_round}
border_width = 1
reduce_motion = ${reduce_motion}
EOF

    local gtkcss
    for gtkcss in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/gtk.css" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"; do
        if [ -f "$gtkcss" ]; then
            sed -i "s|@RADIUS_MD@|${md}|g" "$gtkcss" || true
        fi
    done

    if command -v papirus-folders >/dev/null 2>&1; then
        papirus-folders -C paleorange --theme Papirus-Dark >/dev/null 2>&1 \
            || papirus-folders -C orange --theme Papirus-Dark >/dev/null 2>&1 \
            || true
    fi
}

usage() { grep '^#' "$0" | cut -c3- | head -n26; }

PROFILE=""
WALLPAPER=""
RELOAD=1

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            [ $# -ge 2 ] || die "--profile needs a value"
            PROFILE="$2"; shift 2 ;;
        --wallpaper)
            [ $# -ge 2 ] || die "--wallpaper needs a value"
            WALLPAPER="$2"; shift 2 ;;
        --no-reload) RELOAD=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

command -v matugen >/dev/null 2>&1 || die "matugen not on PATH — see install/manifests/20-theming.aur.txt"
command -v jq >/dev/null 2>&1 || die "jq not on PATH — see install/manifests/00-base.txt"

mkdir -p "$STATE_DIR"

# --- Resolve config.json (falls back to config.default.json), the same
# deep-merge contract as stow/hypr/.config/hypr/modules/config.lua ---
DEFAULT_JSON="$MODERN_DIR/config.default.json"
LIVE_JSON="$MODERN_DIR/config.json"
[ -f "$DEFAULT_JSON" ] || die "missing $DEFAULT_JSON — is the 'modern' stow package installed?"

merged_config() {
    if [ -f "$LIVE_JSON" ]; then
        jq -s '.[0] * .[1]' "$DEFAULT_JSON" "$LIVE_JSON"
    else
        cat "$DEFAULT_JSON"
    fi
}

if [ -z "$PROFILE" ]; then
    PROFILE="$(merged_config | jq -r '.design.activeProfile // "tonal-spot-auto"')"
fi

PROFILE_JSON="$THEMES_DIR/$PROFILE.json"
[ -f "$PROFILE_JSON" ] || die "unknown theme profile '$PROFILE' (no $PROFILE_JSON — see stow/modern/.config/modern/themes/README.md)"

VARIANT="$(jq -r '.variant' "$PROFILE_JSON")"
PROFILE_MODE="$(jq -r '.mode' "$PROFILE_JSON")"
CONTRAST="$(jq -r '.contrast' "$PROFILE_JSON")"
SOURCE_MODE="$(jq -r '.sourceMode' "$PROFILE_JSON")"
FIXED_SEED="$(jq -r '.fixedSeed // empty' "$PROFILE_JSON")"

# matugen's own "smart" mode picks light/dark per-run from the source
# color, which is a better "auto" than a fixed day/night clock heuristic.
case "$PROFILE_MODE" in
    auto) MATUGEN_MODE="smart" ;;
    light|dark) MATUGEN_MODE="$PROFILE_MODE" ;;
    *) die "profile '$PROFILE' has invalid mode '$PROFILE_MODE' (expected auto|light|dark)" ;;
esac

MATUGEN_ARGS=(-c "$MATUGEN_CONFIG" -t "scheme-$VARIANT" -m "$MATUGEN_MODE")

case "$CONTRAST" in
    standard) ;; # matugen's default (0) — no flag needed
    medium) MATUGEN_ARGS+=(--contrast 0.5) ;;
    high) MATUGEN_ARGS+=(--contrast 1) ;;
    *) die "profile '$PROFILE' has invalid contrast '$CONTRAST' (expected standard|medium|high)" ;;
esac

log "profile=$PROFILE variant=$VARIANT mode=$PROFILE_MODE(matugen:$MATUGEN_MODE) contrast=$CONTRAST sourceMode=$SOURCE_MODE"

case "$SOURCE_MODE" in
    fixed)
        [ -n "$FIXED_SEED" ] || die "profile '$PROFILE' has sourceMode=fixed but no fixedSeed"
        MATUGEN_ARGS+=(color hex "$FIXED_SEED")
        ;;
    wallpaper)
        if [ -n "$WALLPAPER" ]; then
            [ -f "$WALLPAPER" ] || die "wallpaper not found: $WALLPAPER"
            echo "$WALLPAPER" > "$WALLPAPER_STATE"
        elif [ -f "$WALLPAPER_STATE" ]; then
            WALLPAPER="$(cat "$WALLPAPER_STATE")"
            [ -f "$WALLPAPER" ] || die "remembered wallpaper no longer exists: $WALLPAPER (pass --wallpaper to set a new one)"
        elif [ -f "$MODERN_DIR/wallpapers/default.jpg" ]; then
            WALLPAPER="$MODERN_DIR/wallpapers/default.jpg"
            echo "$WALLPAPER" > "$WALLPAPER_STATE"
            log "using shipped default wallpaper $WALLPAPER"
        else
            die "profile '$PROFILE' needs a wallpaper and none is set yet — pass --wallpaper /path/to/image.jpg once (Settings > Design and the wallpaper picker do this for you once built, see docs/DECISIONS.md's wallpaper-assets entry)"
        fi
        # --source-color-index 0 picks the single most dominant color
        # deterministically. Without it matugen prompts interactively
        # whenever a wallpaper yields multiple plausible source colors —
        # fine at a terminal, fatal when theme-apply.sh runs from a
        # keybind or the future Settings > Design wallpaper picker with
        # no TTY attached.
        MATUGEN_ARGS+=(image "$WALLPAPER" --source-color-index 0)
        ;;
    *)
        die "profile '$PROFILE' has invalid sourceMode '$SOURCE_MODE' (expected wallpaper|fixed)"
        ;;
esac

# --- Set the wallpaper first (if applicable), then let matugen render
# every configured template from the same seed in one pass ---
if [ "$SOURCE_MODE" = "wallpaper" ] && [ "$RELOAD" -eq 1 ]; then
    if command -v awww >/dev/null 2>&1 && pgrep -x awww-daemon >/dev/null 2>&1; then
        # Default transition — Settings > Design will expose per-call
        # overrides once the wallpaper picker module (docs/DECISIONS.md
        # "wallpaper-assets") lands; today every call gets the same feel.
        awww img "$WALLPAPER" --transition-type wipe --transition-duration 0.8 --transition-fps 60 \
            || warn "awww img failed — is awww-daemon running? (autostart.lua starts it on Hyprland launch)"
    else
        warn "awww-daemon not running — skipping live wallpaper set, only regenerating colors"
    fi
fi

log "running matugen (${MATUGEN_ARGS[*]})"
matugen "${MATUGEN_ARGS[@]}"
log "regenerated tokens.json, Colors.qml, kitty/GTK/Qt/KDE/Vivaldi color files"
patch_toolkit_chrome || warn "toolkit chrome patch skipped"

if [ "$SOURCE_MODE" = "wallpaper" ] && [ -n "$WALLPAPER" ]; then
    sync_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallpaper-sync.sh"
    if [ -f "$sync_script" ]; then
        bash "$sync_script" "$WALLPAPER" || warn "wallpaper-sync.sh failed — lock/login may miss the new image"
    fi
fi

# --- Record state for the future System > Diagnostics view (docs/
# DECISIONS.md "diagnostics") — cheap to write now, useless to add later
# without history ---
jq -n \
    --arg profile "$PROFILE" \
    --arg variant "$VARIANT" \
    --arg mode "$MATUGEN_MODE" \
    --arg contrast "$CONTRAST" \
    --arg sourceMode "$SOURCE_MODE" \
    --arg appliedAt "$(date -Iseconds)" \
    '{profile: $profile, variant: $variant, mode: $mode, contrast: $contrast, sourceMode: $sourceMode, appliedAt: $appliedAt}' \
    > "$LAST_APPLIED_STATE"

if [ "$RELOAD" -eq 0 ]; then
    log "done (--no-reload: skipped live-reload side effects)"
    exit 0
fi

# --- Live-reload what can be reloaded without restarting it ---
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && log "reloaded Hyprland (picks up modules/colors.lua)" \
        || warn "hyprctl reload failed"
else
    log "Hyprland not running — modules/colors.lua will apply on next start"
fi

if command -v kitty >/dev/null 2>&1; then
    kitty @ load-config >/dev/null 2>&1 && log "reloaded kitty colors" \
        || warn "kitty @ load-config failed (remote control off, or no kitty window open) — new windows still pick up the new colors"
fi

# GTK/Qt live-reload (settings.ini re-read, running-app repaint) and the
# Vivaldi Preferences merge: CSS overlay is already on disk from matugen.
# Native theme object is merged only while Vivaldi is not running, so we
# never fight its Preferences writer.
if [ "$RELOAD" -eq 1 ]; then
    merge_vivaldi_theme || warn "vivaldi Preferences merge skipped"
    # QML SystemPalette does not re-read qt6ct when the scheme file
    # changes; the running agent must restart. Style conf live-reloads
    # on its own via hyprland-qt-support's watcher.
    if systemctl --user try-restart hyprpolkitagent.service >/dev/null 2>&1; then
        log "restarted hyprpolkitagent (qt6ct palette + application-style.conf)"
    else
        warn "hyprpolkitagent not restarted — start it from the session or: systemctl --user start hyprpolkitagent"
    fi
fi

log "done (profile=$PROFILE)"
