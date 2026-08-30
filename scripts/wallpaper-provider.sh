#!/usr/bin/env bash
# Wallpaper provider site in its own Qt WebEngine process.
# Embedding WebEngineView in Quickshell aborts: Chromium needs argv[0]
# on QCoreApplication, and the shell starts without one.
set -euo pipefail

URL="${1:-}"
DEST="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$URL" ] || [ -z "$DEST" ]; then
    echo "Usage: wallpaper-provider.sh URL DEST" >&2
    exit 2
fi

QML="$(command -v qml6 || command -v qml || true)"
if [ -z "$QML" ]; then
    echo "wallpaper-provider: qml6 not found" >&2
    exit 127
fi

mkdir -p "$DEST"

notify_new() {
    local f="$1"
    case "${f,,}" in
        *.jpg | *.jpeg | *.png | *.webp)
            stdbuf -oL printf 'INGEST %s\n' "$f" || printf 'INGEST %s\n' "$f"
            ;;
    esac
}

declare -A seen=()
while IFS= read -r -d '' f; do
    seen["$f"]=1
done < <(find "$DEST" -maxdepth 1 -type f -print0 2>/dev/null || true)

qml_pid=""
watch_pid=""
cleanup() {
    if [ -n "${watch_pid:-}" ]; then
        kill "$watch_pid" 2>/dev/null || true
    fi
    if [ -n "${qml_pid:-}" ]; then
        kill "$qml_pid" 2>/dev/null || true
        wait "$qml_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT TERM INT

(
    while true; do
        sleep 1
        while IFS= read -r -d '' f; do
            if [ -z "${seen[$f]+x}" ]; then
                seen["$f"]=1
                notify_new "$f"
            fi
        done < <(find "$DEST" -maxdepth 1 -type f -print0 2>/dev/null || true)
    done
) &
watch_pid=$!

"$QML" -- "$SCRIPT_DIR/wallpaper-provider.qml" "$URL" "$DEST" &
qml_pid=$!
wait "$qml_pid"
