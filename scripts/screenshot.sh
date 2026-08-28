#!/usr/bin/env bash
# Capture a screenshot into config.json's screenshots.directory (default
# ~/Pictures/Screenshots), optionally copy to the clipboard, optionally
# open swappy. Used by Hyprland binds via `modern screenshot <mode>`.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: screenshot.sh <region|window|full>
EOF
}

MODE="${1:-}"
GEOM_ARG="${2:-}"
if [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ] || [ -z "$MODE" ]; then
    usage
    [ -n "$MODE" ] && exit 0
    exit 2
fi

command -v grim >/dev/null 2>&1 || { echo "screenshot: grim not on PATH" >&2; exit 1; }

MODERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
DEFAULT_JSON="$MODERN_DIR/config.default.json"
LIVE_JSON="$MODERN_DIR/config.json"

merged() {
    if [ -f "$LIVE_JSON" ] && [ -f "$DEFAULT_JSON" ]; then
        jq -s '.[0] * .[1]' "$DEFAULT_JSON" "$LIVE_JSON"
    elif [ -f "$LIVE_JSON" ]; then
        cat "$LIVE_JSON"
    elif [ -f "$DEFAULT_JSON" ]; then
        cat "$DEFAULT_JSON"
    else
        echo '{}'
    fi
}

CFG="$(merged)"
DIR="$(jq -r '.screenshots.directory // "~/Pictures/Screenshots"' <<<"$CFG")"
TEMPLATE="$(jq -r '.screenshots.filenameTemplate // "screenshot-%Y%m%d-%H%M%S"' <<<"$CFG")"
COPY="$(jq -r '.screenshots.copyToClipboard // true' <<<"$CFG")"
EDIT="$(jq -r '.screenshots.openEditorAfterCapture // false' <<<"$CFG")"
CURSOR="$(jq -r '.screenshots.includeCursor // false' <<<"$CFG")"

case "$DIR" in
    "~/"*) DIR="$HOME/${DIR#~/}" ;;
esac
if [ -z "$DIR" ]; then
    DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
fi
mkdir -p "$DIR"

# filenameTemplate uses strftime tokens (%Y etc.), not bash date(1) plus.
FILE="$DIR/$(date +"$TEMPLATE").png"

GRIM=(grim)
if [ "$CURSOR" = "true" ]; then
    GRIM+=(-c)
fi

geom=""
slurp_themed() {
    local tokens="${XDG_CONFIG_HOME:-$HOME/.config}/modern/tokens.json"
    if [ -f "$tokens" ]; then
        local scrim primary pcont
        scrim="$(jq -r '.color.scrim' "$tokens")"
        primary="$(jq -r '.color.primary' "$tokens")"
        pcont="$(jq -r '.color.primaryContainer' "$tokens")"
        slurp -b "${scrim}88" -c "$primary" -s "${pcont}44" -w 2
    else
        slurp
    fi
}

case "$MODE" in
    region)
        if [ -n "$GEOM_ARG" ]; then
            # Compositor-global box (slurp / hyprctl monitors), not output-local.
            geom="$GEOM_ARG"
        else
            command -v slurp >/dev/null 2>&1 || { echo "screenshot: slurp not on PATH" >&2; exit 1; }
            geom="$(slurp_themed)" || exit 1
        fi
        "${GRIM[@]}" -g "$geom" "$FILE"
        ;;
    window)
        geom="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        "${GRIM[@]}" -g "$geom" "$FILE"
        ;;
    full)
        "${GRIM[@]}" "$FILE"
        ;;
    *)
        echo "screenshot: unknown mode '$MODE'" >&2
        usage >&2
        exit 2
        ;;
esac

if [ "$COPY" = "true" ] && command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$FILE"
fi

if [ "$EDIT" = "true" ] && command -v swappy >/dev/null 2>&1; then
    swappy -f "$FILE"
fi

printf '%s\n' "$FILE"
