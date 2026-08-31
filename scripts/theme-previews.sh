#!/usr/bin/env bash
# Dry-run unique palettes matugen can extract from a wallpaper.
# Prints a JSON array of {seed,hue,primary,secondary,tertiary,surface}.
# Does not write tokens.json or any other template.
set -euo pipefail

WALLPAPER=""
VARIANT="tonal-spot"
MODE="dark"

die() { printf 'theme-previews: %s\n' "$*" >&2; exit 1; }

hue_id() {
    python3 - "$1" <<'PY' 2>/dev/null || echo accent
import colorsys, sys
h = sys.argv[1].lstrip("#")
if len(h) != 6:
    print("accent")
    raise SystemExit
r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
hue, sat, _ = colorsys.rgb_to_hsv(r, g, b)
if sat < 0.16:
    print("neutral")
    raise SystemExit
d = hue * 360
if d < 15 or d >= 345:
    print("rose")
elif d < 45:
    print("orange")
elif d < 70:
    print("yellow")
elif d < 165:
    print("green")
elif d < 195:
    print("teal")
elif d < 215:
    print("cyan")
elif d < 255:
    print("blue")
elif d < 268:
    print("indigo")
elif d < 322:
    print("violet")
else:
    print("magenta")
PY
}

hue_deg() {
    python3 - "$1" <<'PY' 2>/dev/null || echo 0
import colorsys, sys
h = sys.argv[1].lstrip("#")
if len(h) != 6:
    print(0)
    raise SystemExit
r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
hue, sat, _ = colorsys.rgb_to_hsv(r, g, b)
print(int(round(hue * 360)) if sat >= 0.08 else -1)
PY
}

hue_far() {
    local a="$1" b="$2" d
    [ "$a" -lt 0 ] || [ "$b" -lt 0 ] && return 0
    d=$((a - b))
    [ "$d" -lt 0 ] && d=$((-d))
    [ "$d" -gt 180 ] && d=$((360 - d))
    [ "$d" -ge 28 ]
}

while [ $# -gt 0 ]; do
    case "$1" in
        --wallpaper)
            [ $# -ge 2 ] || die "--wallpaper needs a value"
            WALLPAPER="$2"; shift 2 ;;
        --variant)
            [ $# -ge 2 ] || die "--variant needs a value"
            VARIANT="$2"; shift 2 ;;
        --mode)
            [ $# -ge 2 ] || die "--mode needs a value"
            MODE="$2"; shift 2 ;;
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

raw="$(matugen image "$WALLPAPER" --show-source-colors --dry-run -q 2>/dev/null || true)"
seeds="$(printf '%s\n' "$raw" | grep -E '^#[0-9A-Fa-f]{6}$' || true)"
[ -n "$seeds" ] || { printf '[]\n'; exit 0; }

seen_pri=""
seen_deg=""
items="[]"
count=0
while IFS= read -r seed; do
    [ -n "$seed" ] || continue
    [ "$count" -lt 4 ] || break
    deg="$(hue_deg "$seed")"
    skip=0
    for prev in $seen_deg; do
        hue_far "$deg" "$prev" || skip=1
    done
    [ "$skip" -eq 0 ] || continue
    json="$(matugen color hex "$seed" --dry-run -q -j hex -t "scheme-${VARIANT}" -m "$MODE" 2>/dev/null || true)"
    [ -n "$json" ] || continue
    pri="$(printf '%s' "$json" | jq -r '.colors.primary.default.color // empty')"
    sec="$(printf '%s' "$json" | jq -r '.colors.secondary.default.color // empty')"
    ter="$(printf '%s' "$json" | jq -r '.colors.tertiary.default.color // empty')"
    surf="$(printf '%s' "$json" | jq -r '.colors.surface.default.color // empty')"
    [ -n "$pri" ] || continue
    key="$(printf '%s' "$pri" | tr 'A-F' 'a-f')"
    case " $seen_pri " in
        *" $key "*) continue ;;
    esac
    hue="$(hue_id "$seed")"
    seen_pri="$seen_pri $key"
    seen_deg="$seen_deg $deg"
    count=$((count + 1))
    items="$(jq -c --arg seed "$seed" --arg hue "$hue" --arg pri "$pri" \
        --arg sec "$sec" --arg ter "$ter" --arg surf "$surf" \
        '. + [{seed:$seed,hue:$hue,primary:$pri,secondary:$sec,tertiary:$ter,surface:$surf}]' <<<"$items")"
done <<< "$seeds"

printf '%s\n' "$items"
