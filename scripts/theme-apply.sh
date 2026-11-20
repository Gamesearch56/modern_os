#!/usr/bin/env bash
# Regenerates every theme output file (tokens.json, kitty colors,
# fastfetch, Hyprland border colors, plus the GTK/Qt/KDE/Vivaldi
# templates — see stow/theme/.config/matugen/config.toml) from the active
# theme profile, then reloads the apps that can pick the change up live.
# Quickshell reads tokens.json directly (Commons/Colors.qml FileView).
#
# tokens.json is the single source of truth: everything else in this
# list is generated from the same matugen run, so nothing can drift out
# of sync across per-app templates.
#
# Usage:
#   theme-apply.sh [--profile NAME] [--wallpaper PATH] [--skip-wallpaper]
#                  [--seed HEX] [--extract] [--chrome-only] [--no-reload]
#
#   --profile NAME     Filename without ".json" under
#                       ~/.config/modern/themes or
#                       $XDG_STATE_HOME/modern/themes
#                       (default: config.json's design.activeProfile).
#   --wallpaper PATH   Absolute path to an image. Required the first
#                       time a "sourceMode": "wallpaper" profile is
#                       applied; remembered afterwards in
#                       $STATE_DIR/current-wallpaper. Also sets the
#                       wallpaper itself via awww, with a transition,
#                       unless --skip-wallpaper (picker already showed it).
#   --skip-wallpaper   Remember --wallpaper / regenerate colors only;
#                       do not call awww (avoids a second delayed fade).
#                       The login snapshot still updates from --wallpaper.
#   --seed HEX         Use this source color (from theme-previews.sh)
#                       instead of extracting from the wallpaper.
#   --extract          Ignore a stored source seed and extract again
#                       from the wallpaper (--prefer saturation).
#   --surface-tint N   Accepted from the Design slider. Shell surfaces
#                       read it from config; it is not a matugen contrast.
#   --chrome-only      Patch GTK/Qt/KDE/Vivaldi radii, fonts, and motion
#                       from config.json without re-running matugen.
#   --no-reload        Write files (including Vivaldi Preferences) but
#                       skip compositor reload. Used by install.sh and
#                       CI, where no Hyprland session is running.
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
# shellcheck source=lib/theme-seed.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/theme-seed.sh"
WALLPAPER_STATE="$STATE_DIR/current-wallpaper"
LAST_APPLIED_STATE="$STATE_DIR/theme-last-applied.json"
MATUGEN_CONFIG="$HOME/.config/matugen/config.toml"

log()  { printf '\033[36m[theme-apply]\033[0m %s\n' "$*" || true; }
warn() { printf '\033[33m[theme-apply] WARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[theme-apply] ERROR\033[0m %s\n' "$*" >&2; exit 1; }

# Stow may leave ~/.config/fastfetch as a dangling symlink if this
# package's tree was missing. matugen then prints "folder doesnt exist,
# trying to create" and dies with EEXIST — wallpaper apply toasts that.
ensure_writable_dir() {
    local dir="$1"
    if [ -L "$dir" ] && [ ! -e "$dir" ]; then
        rm -f "$dir"
    fi
    mkdir -p "$dir"
}

# Variant-mode slugs Settings creates on the fly (tonal-spot-light, …)
# when no JSON was shipped. Longest variant names first.
KNOWN_VARIANTS="fruit-salad tonal-spot monochrome expressive fidelity rainbow vibrant content neutral"

synthesize_profile() {
    local slug="$1" v rest mode contrast source
    contrast="standard"
    source="wallpaper"
    rest=""
    VARIANT=""
    for v in $KNOWN_VARIANTS; do
        case "$slug" in
            "$v"-*)
                rest="${slug#"$v"-}"
                VARIANT="$v"
                break
                ;;
        esac
    done
    [ -n "$VARIANT" ] && [ -n "$rest" ] || return 1
    mode="${rest%%-*}"
    case "$mode" in
        light|dark|auto) ;;
        *) return 1 ;;
    esac
    rest="${rest#"$mode"}"
    rest="${rest#-}"
    while [ -n "$rest" ]; do
        case "$rest" in
            medium*) contrast="medium"; rest="${rest#medium}" ;;
            high*) contrast="high"; rest="${rest#high}" ;;
            fixed*) source="fixed"; rest="${rest#fixed}" ;;
            *) return 1 ;;
        esac
        rest="${rest#-}"
    done
    mkdir -p "$STATE_DIR/themes"
    PROFILE_JSON="$STATE_DIR/themes/${slug}.json"
    jq -n --arg v "$VARIANT" --arg m "$mode" --arg c "$contrast" --arg s "$source" \
        '{variant:$v,mode:$m,contrast:$c,sourceMode:$s,fixedSeed:null}' > "$PROFILE_JSON"
    log "synthesized profile $PROFILE_JSON"
}

# libadwaita / xdg-desktop-portal / GTK read this; keep it in sync with
# the matugen light|dark scheme so other apps follow Settings → Design.
apply_color_scheme() {
    local dark="$1" scheme gtk_dark
    if [ "$dark" = 1 ]; then
        scheme="prefer-dark"
        gtk_dark=1
    else
        scheme="prefer-light"
        gtk_dark=0
    fi
    # A new account is themed before it has a session bus. A private
    # bus still writes dconf, which the portal reads on the first login.
    if command -v gsettings >/dev/null 2>&1; then
        if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
            gsettings set org.gnome.desktop.interface color-scheme "$scheme" >/dev/null 2>&1 || true
        elif command -v dbus-run-session >/dev/null 2>&1; then
            dbus-run-session -- gsettings set org.gnome.desktop.interface color-scheme "$scheme" >/dev/null 2>&1 || true
        fi
    fi
    local gini
    for gini in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/settings.ini"; do
        if [ -f "$gini" ]; then
            if grep -q '^gtk-application-prefer-dark-theme=' "$gini"; then
                sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=${gtk_dark}/" "$gini"
            else
                printf '\ngtk-application-prefer-dark-theme=%s\n' "$gtk_dark" >> "$gini"
            fi
        fi
    done
}

# Native theme + CSS-mods path. Creates Preferences on a fresh home
# (install --no-reload). Skips an existing file while Vivaldi is open
# and reapplies on quit so a restart picks up the new palette.
merge_vivaldi_theme() {
    # shellcheck source=lib/vivaldi-prefs.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/vivaldi-prefs.sh"
    local st=0
    merge_vivaldi_prefs "$MODERN_DIR/tokens.json" || st=$?
    case "$st" in
        0) log "merged Vivaldi native theme (id=modern)" ;;
        2) log "Vivaldi is running — native theme applies on quit" ;;
        *) warn "Vivaldi native theme merge skipped" ;;
    esac
    return 0
}

# Apple-tab folders from matugen tokens. Own theme name so we Inherits=
# Papirus-Dark instead of shadowing it (same-name inherit is a no-op).
overlay_folder_icons() {
    local inherit="$1"
    local dest="${XDG_DATA_HOME:-$HOME/.local/share}/icons/modern-folders"
    local src="$dest/scalable/places/folder.svg"
    mkdir -p "$dest/scalable/places" "$dest/64x64/places"
    [ -f "$src" ] || return 0
    cat > "$dest/index.theme" <<EOF
[Icon Theme]
Name=modern-folders
Comment=Papirus with ModernOS folders
Inherits=${inherit},hicolor
Directories=scalable/places,64x64/places

[scalable/places]
Size=64
Context=Places
Type=Scalable
MinSize=16
MaxSize=256

[64x64/places]
Size=64
Context=Places
Type=Fixed
EOF
    local name
    for name in folder folder-open inode-directory user-home folder-download \
        folder-pictures folder-documents folder-music folder-videos; do
        if [ "$name" != folder ]; then
            cp -f -- "$src" "$dest/scalable/places/${name}.svg"
        fi
        cp -f -- "$src" "$dest/64x64/places/${name}.svg"
    done
    gtk-update-icon-cache -f -t "$dest" >/dev/null 2>&1 &
    disown $! 2>/dev/null || true
}

patch_toolkit_chrome() {
    local cfg radius font mono blur trans
    cfg="$(merged_config)"
    radius="$(jq -r '.design.cornerRounding // 1' <<<"$cfg")"
    font="$(jq -r '.typography.ui // "Inter"' <<<"$cfg")"
    mono="$(jq -r '.typography.monospace // "JetBrainsMono Nerd Font"' <<<"$cfg")"
    blur="$(jq -r '.design.blurStrength // 40' <<<"$cfg")"
    trans="$(jq -r '.design.transparency // 0.85' <<<"$cfg")"
    local scale pt mpt cursor_theme cursor_size icon
    scale="$(jq -r '.typography.scale // 1' <<<"$cfg")"
    pt="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 11*s }')"
    mpt="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 10*s }')"
    cursor_theme="$(jq -r '.design.cursorTheme // "Bibata-Modern-Classic"' <<<"$cfg")"
    cursor_size="$(jq -r '.design.cursorSize // 24' <<<"$cfg")"
    icon="$(jq -r '.design.iconTheme // "Papirus-Dark"' <<<"$cfg")"
    local prefer_dark
    prefer_dark="$(scheme_is_dark)"
    if [ "$prefer_dark" = 0 ]; then
        case "$icon" in Papirus-Dark) icon="Papirus-Light" ;; esac
    else
        case "$icon" in Papirus-Light) icon="Papirus-Dark" ;; esac
    fi
    apply_color_scheme "$prefer_dark"
    overlay_folder_icons "$icon"
    local kde_icon="$icon"
    local gtk_icon="$icon"
    if [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/icons/modern-folders/scalable/places/folder.svg" ]; then
        case "$icon" in
            Papirus|Papirus-Dark|Papirus-Light)
                # Nautilus keeps Papirus emblem folders; Dolphin uses the overlay.
                kde_icon=modern-folders
                ;;
        esac
    fi
    local sm md lg
    sm="$(awk -v r="$radius" 'BEGIN { printf "%.0f", 8*r }')"
    md="$(awk -v r="$radius" 'BEGIN { printf "%.0f", 16*r }')"
    lg="$(awk -v r="$radius" 'BEGIN { printf "%.0f", 28*r }')"
    local css_dir="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi/custom_css"
    mkdir -p "$css_dir"
    rm -f "$css_dir/00-wallust.css" "$css_dir/wallust.css"
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
  --md-font-scale: ${scale};
}
body, #browser {
  font-family: var(--md-font-ui), sans-serif !important;
  zoom: var(--md-font-scale);
}
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
            -e "s|@SPACE_XXS@|2|g" \
            -e "s|@SPACE_XS@|4|g" \
            -e "s|@SPACE_SM@|8|g" \
            -e "s|@SPACE_MD@|12|g" \
            -e "s|@SPACE_LG@|16|g" \
            -e "s|@SPACE_XL@|24|g" \
            "$qss" > "$tmp" && mv "$tmp" "$qss"
    fi
    local kde="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
    if [ -f "$kde" ]; then
        awk -v font="$font" -v mono="$mono" -v pt="$pt" -v icon="$kde_icon" '
            BEGIN { g=0; i=0 }
            /^\[General\]/ { print; print "font=" font "," pt ",-1,5,50,0,0,0,0,0"; print "fixed=" mono "," pt ",-1,5,50,0,0,0,0,0"; g=1; next }
            /^\[Icons\]/ { print; print "Theme=" icon; i=1; next }
            /^widgetStyle=/ { print "widgetStyle=qt6ct-style"; next }
            { print }
            END {
              if (!g) { print "[General]"; print "font=" font "," pt ",-1,5,50,0,0,0,0,0" }
              if (!i) { print "[Icons]"; print "Theme=" icon }
            }
        ' "$kde" > "$kde.tmp" && mv "$kde.tmp" "$kde"
    fi
    local qtconf="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"
    if [ -f "$qtconf" ]; then
        local scheme_abs
        scheme_abs="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/modern.conf"
        awk -v icon="$icon" -v scheme="$scheme_abs" -v font="$font" -v mono="$mono" -v pt="$pt" -v mpt="$mpt" '
            /^\[Appearance\]/ { print; print "color_scheme_path=" scheme; next }
            /^color_scheme_path=/ { next }
            /^icon_theme=/ { print "icon_theme=" icon; next }
            /^style=/ { print "style=qt6ct-style"; next }
            /^stylesheets=/ { print "stylesheets="; next }
            /^general=/ { print "general=@ByteArray(" font "," pt ",-1,5,50,0,0,0,0,0)"; next }
            /^fixed=/ { print "fixed=@ByteArray(" mono "," mpt ",-1,5,50,0,0,0,0,0)"; next }
            { print }
        ' "$qtconf" > "$qtconf.tmp" && mv "$qtconf.tmp" "$qtconf"
    fi

    # Other hypr* Qt Quick apps still read chrome from
    # ~/.config/hypr/application-style.conf — QSS never reaches that QML
    # style. Enum steps are 0/4/8/16 px; Tokens.radius.medium is 16 * rounding.
    local hypr_round=2
    if [ "$md" -le 2 ]; then
        hypr_round=0
    elif [ "$md" -le 6 ]; then
        hypr_round=1
    elif [ "$md" -le 12 ]; then
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
# hyprland-qt-support (other hypr* Qt Quick apps). See docs/THEMING.md.
roundness = ${hypr_round}
border_width = 1
reduce_motion = ${reduce_motion}
EOF

    # Other hyprtoolkit apps still read hyprtoolkit.conf. Phylax (polkit)
    # uses ~/.config/phylax/style.css from the matugen template instead.
    local tokens="$MODERN_DIR/tokens.json"
    local toolkit_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprtoolkit.conf"
    if [ -f "$tokens" ]; then
        local h1 h2 h3 body small
        local c_surface c_base c_alt c_text c_bright c_accent c_secondary
        h1="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 24*s }')"
        h2="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 16*s }')"
        h3="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 14*s }')"
        body="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 14*s }')"
        small="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 12*s }')"
        c_surface="$(jq -r '.color.surface' "$tokens" | tr -d '#')"
        c_base="$(jq -r '.color.surfaceContainerHighest' "$tokens" | tr -d '#')"
        c_alt="$(jq -r '.color.surfaceContainer' "$tokens" | tr -d '#')"
        c_text="$(jq -r '.color.onSurface' "$tokens" | tr -d '#')"
        c_bright="$(jq -r '.color.onPrimary' "$tokens" | tr -d '#')"
        c_accent="$(jq -r '.color.primary' "$tokens" | tr -d '#')"
        c_secondary="$(jq -r '.color.secondary' "$tokens" | tr -d '#')"
        cat > "$toolkit_conf" <<EOF
# GENERATED by scripts/theme-apply.sh — do not hand-edit.
# Overlay chrome for hyprtoolkit apps. Phylax (polkit) reads style.css.
background = 0xFF${c_surface}
base = 0xFF${c_base}
alternate_base = 0xFF${c_alt}
text = 0xFF${c_text}
bright_text = 0xFF${c_bright}
accent = 0xFF${c_accent}
accent_secondary = 0xFF${c_secondary}
h1_size = ${h1}
h2_size = ${h2}
h3_size = ${h3}
font_size = ${body}
small_font_size = ${small}
icon_theme = ${icon}
font_family = ${font}
font_family_monospace = ${mono}
rounding_large = ${md}
rounding_small = ${sm}
EOF
    fi

    local gtkcss
    for gtkcss in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/gtk.css" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"; do
        if [ -f "$gtkcss" ]; then
            sed -i "s|@RADIUS_MD@|${md}|g" "$gtkcss" || true
        fi
    done

    local phylax_dir="${XDG_CONFIG_HOME:-$HOME/.config}/phylax"
    mkdir -p "$phylax_dir"
    local phylax_css="$phylax_dir/style.css"
    if [ -f "$phylax_css" ]; then
        local body tmp
        body="$(awk -v s="$scale" 'BEGIN { printf "%.0f", 14*s }')"
        tmp="$(mktemp)"
        sed \
            -e "s|@FONT_UI@|${font}|g" \
            -e "s|@FONT_SIZE@|${body}|g" \
            -e "s|@RADIUS_SM@|${sm}|g" \
            -e "s|@RADIUS_MD@|${md}|g" \
            -e "s|@RADIUS_FULL@|9999|g" \
            -e "s|@SPACE_SM@|8|g" \
            -e "s|@SPACE_MD@|12|g" \
            -e "s|@SPACE_LG@|16|g" \
            -e "s|@STROKE_FOCUS@|2|g" \
            "$phylax_css" > "$tmp" && mv "$tmp" "$phylax_css"
    fi

    local gini
    for gini in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/settings.ini"; do
        if [ -f "$gini" ]; then
            awk -v font="$font $pt" -v cursor="$cursor_theme" -v csize="$cursor_size" -v icon="$gtk_icon" -v dark="$prefer_dark" '
                /^gtk-font-name=/ { print "gtk-font-name=" font; next }
                /^gtk-cursor-theme-name=/ { print "gtk-cursor-theme-name=" cursor; next }
                /^gtk-cursor-theme-size=/ { print "gtk-cursor-theme-size=" csize; next }
                /^gtk-icon-theme-name=/ { print "gtk-icon-theme-name=" icon; next }
                /^gtk-application-prefer-dark-theme=/ { print "gtk-application-prefer-dark-theme=" dark; next }
                { print }
            ' "$gini" > "$gini.tmp" && mv "$gini.tmp" "$gini"
        fi
    done

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface font-name "$font $pt" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface document-font-name "$font $pt" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface monospace-font-name "$mono $pt" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface cursor-size "$cursor_size" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface icon-theme "$gtk_icon" >/dev/null 2>&1 || true
    fi
}

scheme_is_dark() {
    local m
    m="$(jq -r '.mode // empty' "$MODERN_DIR/tokens.json" 2>/dev/null || true)"
    case "$m" in
        light) echo 0; return ;;
        dark) echo 1; return ;;
    esac
    case "${MATUGEN_MODE:-}" in
        light) echo 0 ;;
        *) echo 1 ;;
    esac
}

usage() { grep '^#' "$0" | cut -c3- | head -n32; }

PROFILE=""
WALLPAPER=""
SEED=""
SURFACE_TINT=""
EXTRACT=0
RELOAD=1
CHROME_ONLY=0
SKIP_WALLPAPER=0
WALLPAPER_EXPLICIT=0
EXTRACTED_IMAGE=0
SYNC_WALLPAPER=0

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            [ $# -ge 2 ] || die "--profile needs a value"
            PROFILE="$2"; shift 2 ;;
        --wallpaper)
            [ $# -ge 2 ] || die "--wallpaper needs a value"
            WALLPAPER="$2"; WALLPAPER_EXPLICIT=1; shift 2 ;;
        --seed)
            [ $# -ge 2 ] || die "--seed needs a value"
            SEED="$2"; shift 2 ;;
        --surface-tint)
            [ $# -ge 2 ] || die "--surface-tint needs a value"
            SURFACE_TINT="$2"; shift 2 ;;
        --extract) EXTRACT=1; shift ;;
        --skip-wallpaper) SKIP_WALLPAPER=1; shift ;;
        --chrome-only) CHROME_ONLY=1; shift ;;
        --no-reload) RELOAD=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

command -v jq >/dev/null 2>&1 || die "jq not on PATH — see install/manifests/00-base.txt"

mkdir -p "$STATE_DIR"
# Picker generates the palette in parallel with the crop. Remember the
# transition file's time so a later reload can wait for this run's mark
# instead of the previous wallpaper's.
WALLPAPER_MARK="$STATE_DIR/wallpaper-transition"
WALLPAPER_MARK_BODY=""
if [ -f "$WALLPAPER_MARK" ]; then
    WALLPAPER_MARK_BODY="$(head -n 1 "$WALLPAPER_MARK" 2>/dev/null || true)"
fi

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

if [ "$CHROME_ONLY" -eq 1 ]; then
    patch_toolkit_chrome || warn "toolkit chrome patch skipped"
    merge_vivaldi_theme || true
    # Fonts/radii also live in phylax/style.css — reload when not racing.
    # shellcheck source=lib/polkit-agent.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/polkit-agent.sh"
    reload_polkit_theme || true
    log "done (--chrome-only)"
    exit 0
fi

command -v matugen >/dev/null 2>&1 || die "matugen not on PATH — see install/manifests/20-theming.aur.txt"

if [ -z "$PROFILE" ]; then
    PROFILE="$(merged_config | jq -r '.design.activeProfile // "tonal-spot-auto"')"
fi

PROFILE_JSON="$THEMES_DIR/$PROFILE.json"
if [ ! -f "$PROFILE_JSON" ]; then
    PROFILE_JSON="$STATE_DIR/themes/$PROFILE.json"
fi
if [ ! -f "$PROFILE_JSON" ]; then
    synthesize_profile "$PROFILE" || die "unknown theme profile '$PROFILE' (no $THEMES_DIR/$PROFILE.json or $STATE_DIR/themes/$PROFILE.json — see stow/modern/.config/modern/themes/README.md)"
fi

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
    standard) CONTRAST_NUM=0 ;;
    medium) CONTRAST_NUM=0.5 ;;
    high) CONTRAST_NUM=1 ;;
    *) die "profile '$PROFILE' has invalid contrast '$CONTRAST' (expected standard|medium|high)" ;;
esac
if [ -z "$SURFACE_TINT" ]; then
    SURFACE_TINT="$(merged_config | jq -r '.design.surfaceTint // 0.7')"
fi
# Negative contrast (the old surface-tint coupling) lifts light-mode
# on-colors toward the surface, so body text goes gray on cream and
# on-background falls under 3:1. The profile contrast is the palette;
# the slider tints shell surfaces through Tokens.
if ! awk -v c="$CONTRAST_NUM" 'BEGIN { exit (c + 0 == 0) ? 0 : 1 }'; then
    MATUGEN_ARGS+=(--contrast "$CONTRAST_NUM")
fi

log "profile=$PROFILE variant=$VARIANT mode=$PROFILE_MODE(matugen:$MATUGEN_MODE) contrast=$CONTRAST (matugen $CONTRAST_NUM) surfaceTint=$SURFACE_TINT sourceMode=$SOURCE_MODE"

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
        # --seed is a palette card (or a locked sourceSeed). --extract
        # must ignore tokens.json's last sourceColor — that is the
        # previous wallpaper's seed and would freeze every later apply.
        if [ "$EXTRACT" -eq 1 ]; then
            SEED=""
        elif [ -z "$SEED" ]; then
            SEED="$(merged_config | jq -r '.design.sourceSeed // empty')"
        fi
        if [ "$EXTRACT" -eq 0 ] && [ -z "$SEED" ] && [ -f "$MODERN_DIR/tokens.json" ]; then
            SEED="$(jq -r '.sourceColor // empty' "$MODERN_DIR/tokens.json")"
        fi
        # Same pixels matugen would score (full image, its own 112px
        # resize). The cache only skips that decode when this exact file
        # was scored before, so a repeat pick matches the first one.
        if [ -z "$SEED" ]; then
            SEED="$(theme_cached_seed "$WALLPAPER" || true)"
        fi
        if [ -n "$SEED" ]; then
            MATUGEN_ARGS+=(color hex "$SEED")
        else
            MATUGEN_ARGS+=(image "$WALLPAPER" --prefer saturation)
            EXTRACTED_IMAGE=1
        fi
        ;;
    *)
        die "profile '$PROFILE' has invalid sourceMode '$SOURCE_MODE' (expected wallpaper|fixed)"
        ;;
esac

# --- Set the wallpaper first (if applicable), then let matugen render
# every configured template from the same seed in one pass ---
if [ "$SOURCE_MODE" = "wallpaper" ] && [ "$RELOAD" -eq 1 ] && [ "$SKIP_WALLPAPER" -eq 0 ]; then
    show_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallpaper-show.sh"
    if [ -x "$show_script" ] || [ -f "$show_script" ]; then
        bash "$show_script" "$WALLPAPER" \
            || warn "awww img failed — is awww-daemon running? (autostart.lua starts it on Hyprland launch)"
    else
        warn "wallpaper-show.sh missing — skipping live wallpaper set"
    fi
fi

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
ensure_writable_dir "$cfg/phylax"
ensure_writable_dir "$cfg/fastfetch"
ensure_writable_dir "$cfg/kitty"
ensure_writable_dir "$cfg/vivaldi/custom_css"

log "running matugen (${MATUGEN_ARGS[*]})"
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/icons/modern-folders/scalable/places"
matugen "${MATUGEN_ARGS[@]}"
if [ "$EXTRACTED_IMAGE" -eq 1 ] && [ -n "$WALLPAPER" ] && [ -f "$MODERN_DIR/tokens.json" ]; then
    theme_store_seed "$WALLPAPER" "$(jq -r '.sourceColor // empty' "$MODERN_DIR/tokens.json")" || true
fi
log "regenerated tokens.json, kitty/fastfetch/GTK/Qt/KDE/Vivaldi color files"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/system-icons.sh" || true

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

sync_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallpaper-sync.sh"
if [ "$SOURCE_MODE" = "wallpaper" ] && [ -n "$WALLPAPER" ] \
    && { [ "$SKIP_WALLPAPER" -eq 0 ] || [ "$WALLPAPER_EXPLICIT" -eq 1 ]; }; then
    # Login copies re-encode and blur the full image. That is not the
    # shell palette (tokens.json is already written). On a slow machine
    # it kept the UI from painting the new colors for seconds. A live
    # session does this after the palette reload; install still waits.
    SYNC_WALLPAPER=1
    if [ "$RELOAD" -eq 0 ] && [ -f "$sync_script" ]; then
        bash "$sync_script" "$WALLPAPER" || warn "wallpaper-sync.sh failed — lock/login may miss the new image"
    fi
elif [ -f "$MODERN_DIR/tokens.json" ]; then
    shared="${XDG_STATE_HOME:-$HOME/.local/state}/modern/session"
    [ -d /var/lib/modern/session ] && shared="/var/lib/modern/session"
    mkdir -p "$shared"
    cp -f "$MODERN_DIR/tokens.json" "$shared/tokens.json" || true
fi

jq -n \
    --arg profile "$PROFILE" \
    --arg variant "$VARIANT" \
    --arg mode "$MATUGEN_MODE" \
    --arg contrast "$CONTRAST" \
    --arg sourceMode "$SOURCE_MODE" \
    --arg appliedAt "$(date -Iseconds)" \
    '{profile: $profile, variant: $variant, mode: $mode, contrast: $contrast, sourceMode: $sourceMode, appliedAt: $appliedAt}' \
    > "$LAST_APPLIED_STATE"

finish_live() {
    patch_toolkit_chrome || warn "toolkit chrome patch skipped"
    if command -v kitty >/dev/null 2>&1; then
        kitty @ load-config >/dev/null 2>&1 || true
    fi
    merge_vivaldi_theme || true
    if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        # shellcheck source=lib/hypr-watch.sh
        source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/hypr-watch.sh"
        clear_hypr_reload_banner
    fi
    # Phylax loads style.css once at start — bounce so wallpaper palettes
    # land on the next pkexec. Debounced inside reload_polkit_theme.
    # shellcheck source=lib/polkit-agent.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/polkit-agent.sh"
    reload_polkit_theme || true
    if [ "$SYNC_WALLPAPER" -eq 1 ] && [ -f "$sync_script" ]; then
        if command -v nice >/dev/null 2>&1; then
            nice -n 19 bash "$sync_script" "$WALLPAPER" \
                || warn "wallpaper-sync.sh failed — lock/login may miss the new image"
        else
            bash "$sync_script" "$WALLPAPER" \
                || warn "wallpaper-sync.sh failed — lock/login may miss the new image"
        fi
    fi
}

if [ "$RELOAD" -eq 0 ]; then
    patch_toolkit_chrome || warn "toolkit chrome patch skipped"
    merge_vivaldi_theme || true
    log "done (--no-reload: skipped compositor reload)"
    exit 0
fi

# tokens.json already restyled the shell, which holds that palette until
# the wallpaper transition. Other apps reload once that transition has
# started, so they do not recolor the old picture. GTK/Qt/gsettings stay
# off the Settings spinner.
wait_for_wallpaper_transition() {
    [ "$SKIP_WALLPAPER" -eq 1 ] || return 0
    [ "$WALLPAPER_EXPLICIT" -eq 1 ] || return 0
    local waited=0 line
    while [ "$waited" -lt 200 ]; do
        if [ -f "$WALLPAPER_MARK" ]; then
            line="$(head -n 1 "$WALLPAPER_MARK" 2>/dev/null || true)"
            if [ "$line" != "$WALLPAPER_MARK_BODY" ]; then
                case "$line" in
                    start\ *|done\ *) return 0 ;;
                esac
            fi
        fi
        sleep 0.1
        waited=$((waited + 1))
    done
}
(
    wait_for_wallpaper_transition
    finish_live
) </dev/null >/dev/null 2>&1 &
disown $! 2>/dev/null || true

log "done (profile=$PROFILE)"
