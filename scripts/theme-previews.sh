#!/usr/bin/env bash
# Dry-run one palette per matugen scheme from the current wallpaper.
# Uses the same --prefer saturation seed as theme-apply.sh --extract.
# Prints JSON [{variant,seed,primary,secondary,tertiary,surface,onSurface}].
# Does not write tokens.json or any other template.
set -euo pipefail

WALLPAPER=""
MODE="dark"

die() { printf 'theme-previews: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --wallpaper)
            [ $# -ge 2 ] || die "--wallpaper needs a value"
            WALLPAPER="$2"; shift 2 ;;
        --mode)
            [ $# -ge 2 ] || die "--mode needs a value"
            MODE="$2"; shift 2 ;;
        --variant)
            [ $# -ge 2 ] || die "--variant needs a value"
            shift 2 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[ -n "$WALLPAPER" ] || die "missing --wallpaper"
[ -f "$WALLPAPER" ] || die "wallpaper not found: $WALLPAPER"
command -v matugen >/dev/null 2>&1 || die "matugen not on PATH"
command -v jq >/dev/null 2>&1 || die "jq not on PATH"

case "$MODE" in
    light|dark) ;;
    *) MODE="dark" ;;
esac

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/modern"
# shellcheck source=lib/theme-seed.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/theme-seed.sh"

# Same scored color theme-apply.sh keeps. Light and dark only change
# the scheme built from that color, so a mode switch must not decode
# the wallpaper again.
seed="$(theme_cached_seed "$WALLPAPER" || true)"
if [ -n "$seed" ]; then
    json="$(matugen color hex "$seed" --dry-run -q -j hex \
        -t scheme-tonal-spot -m "$MODE" --include-image-in-json false 2>/dev/null || true)"
else
    json="$(matugen image "$WALLPAPER" --prefer saturation --dry-run -q -j hex \
        -t scheme-tonal-spot -m "$MODE" --include-image-in-json false 2>/dev/null || true)"
    seed="$(printf '%s' "$json" | jq -r '.colors.source_color.default.color // empty')"
    [ -n "$seed" ] && theme_store_seed "$WALLPAPER" "$seed" || true
fi
[ -n "$seed" ] || { printf '[]\n'; exit 0; }

pick() {
    printf '%s' "$1" | jq -r "$2"
}

items="[]"
first=1
for variant in tonal-spot expressive vibrant fidelity content fruit-salad rainbow neutral monochrome; do
    if [ "$first" -eq 1 ]; then
        first=0
    else
        json="$(matugen color hex "$seed" --dry-run -q -j hex \
            -t "scheme-${variant}" -m "$MODE" --include-image-in-json false 2>/dev/null || true)"
    fi
    [ -n "$json" ] || continue
    pri="$(pick "$json" '.colors.primary.default.color // empty')"
    [ -n "$pri" ] || continue
    items="$(jq -c --arg variant "$variant" --arg seed "$seed" \
        --arg pri "$pri" \
        --arg sec "$(pick "$json" '.colors.secondary.default.color // empty')" \
        --arg ter "$(pick "$json" '.colors.tertiary.default.color // empty')" \
        --arg surf "$(pick "$json" '.colors.surface.default.color // empty')" \
        --arg on "$(pick "$json" '.colors.on_surface.default.color // empty')" \
        '. + [{variant:$variant,seed:$seed,primary:$pri,secondary:$sec,tertiary:$ter,surface:$surf,onSurface:$on}]' \
        <<<"$items")"
done

printf '%s\n' "$items"
