#!/usr/bin/env bash
# Merge one dotted path into the live config.json. Invoked by the
# Settings app via Services/ConfigWrite (and `modern config set`) so
# Commons/Config.qml can stay a read-only FileView — a QML writeAdapter
# on that singleton would make every widget a potential writer.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: config-set.sh PATH VALUE

PATH is a dotted JSON path (e.g. motion.scale). VALUE must be JSON
(--argjson): 1.2, "tonal-spot-auto", true, {"a":1}.

Writes $XDG_CONFIG_HOME/modern/config.json (default ~/.config/modern/).
Creates it from config.default.json when missing.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi
if [ $# -ne 2 ]; then
    usage >&2
    exit 2
fi

PATH_EXPR="$1"
VALUE_JSON="$2"

if [[ ! "$PATH_EXPR" =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)*$ ]]; then
    echo "config-set: invalid path: $PATH_EXPR" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "config-set: jq is required" >&2
    exit 1
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/modern"
CFG="$CONFIG_HOME/config.json"
DEFAULT="$CONFIG_HOME/config.default.json"

mkdir -p "$CONFIG_HOME"

exec 9>"$CONFIG_HOME/config.json.lock"
flock -x 9

if [ ! -f "$CFG" ]; then
    if [ ! -f "$DEFAULT" ]; then
        echo "config-set: missing $CFG and $DEFAULT" >&2
        exit 1
    fi
    cp -- "$DEFAULT" "$CFG"
fi

if ! jq -n --argjson v "$VALUE_JSON" '$v' >/dev/null; then
    echo "config-set: VALUE is not valid JSON" >&2
    exit 2
fi

tmp="$(mktemp "$CONFIG_HOME/config.json.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT

jq --arg p "$PATH_EXPR" --argjson v "$VALUE_JSON" \
    'setpath($p | split("."); $v)' "$CFG" >"$tmp"

# Same-directory rename so FileView never sees a missing path (mv from
# /tmp is copy+unlink and toasts "failed to load config.json: 2").
mv -f -- "$tmp" "$CFG"
trap - EXIT
echo "updated $PATH_EXPR"
