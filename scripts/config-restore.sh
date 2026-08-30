#!/usr/bin/env bash
# Copy one or more dotted paths from config.default.json onto the live
# config.json. Settings Restore uses this so Commons/Config stays
# read-only and ConfigWrite can reset a page in one write.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: config-restore.sh PATH [PATH...]

Each PATH is a dotted JSON path (e.g. general.dndSchedule). Values are
copied from config.default.json onto config.json.

Writes $XDG_CONFIG_HOME/modern/config.json (default ~/.config/modern/).
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi
if [ $# -lt 1 ]; then
    usage >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "config-restore: jq is required" >&2
    exit 1
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
CFG="$CONFIG_HOME/config.json"
DEFAULT="$CONFIG_HOME/config.default.json"

if [ ! -f "$DEFAULT" ]; then
    echo "config-restore: missing $DEFAULT" >&2
    exit 1
fi
if [ ! -f "$CFG" ]; then
    cp -- "$DEFAULT" "$CFG"
fi

path_ok='^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)*$'
for p in "$@"; do
    if [[ ! "$p" =~ $path_ok ]]; then
        echo "config-restore: invalid path: $p" >&2
        exit 2
    fi
done

PATHS_JSON="$(printf '%s\n' "$@" | jq -R . | jq -s .)"

tmp="$(mktemp "$CONFIG_HOME/config.json.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT

jq --slurpfile def "$DEFAULT" --argjson paths "$PATHS_JSON" '
    reduce $paths[] as $p (.;
        ($def[0] | getpath($p | split("."))) as $v
        | if $v == null then
            error("config-restore: missing default \( $p )")
          else
            setpath($p | split("."); $v)
          end
    )
' "$CFG" >"$tmp"

mv -f -- "$tmp" "$CFG"
trap - EXIT
echo "restored $*"
