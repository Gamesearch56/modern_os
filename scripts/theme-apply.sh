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
    local primary surface on_surface
    primary="$(jq -r '.color.primary' "$tokens")"
    surface="$(jq -r '.color.surface' "$tokens")"
    on_surface="$(jq -r '.color.onSurface' "$tokens")"
    jq \
        --arg bg "$surface" \
        --arg fg "$on_surface" \
        --arg accent "$primary" \
        '.vivaldi.themes.current = "modern"
         | .vivaldi.themes.user = ((.vivaldi.themes.user // []) | map(select(.id != "modern")))
           + [{id:"modern", name:"modern",
               colorBg:$bg, colorFg:$fg, colorAccentBg:$accent,
               accentOnWindow:false, accentFromPage:false}]' \
        "$prefs" > "$prefs.tmp" && mv "$prefs.tmp" "$prefs"
    log "merged Vivaldi native theme (id=modern)"
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

kitty_colors="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/colors.conf"
if [ ! -f "$kitty_colors" ]; then
    mkdir -p "$(dirname "$kitty_colors")"
    rm -f "$kitty_colors"
    warn "matugen did not write $kitty_colors — seeding MD3 dark stub"
    cat > "$kitty_colors" <<'EOF'
# Shipped MD3 dark baseline (same seed as Commons/Colors.qml).
background #141218
foreground #E6E0E9
cursor #D0BCFF
selection_background #4A4458
selection_foreground #E8DEF8
EOF
fi

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
fi

log "done (profile=$PROFILE)"
