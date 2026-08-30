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
    [ -f "$f" ] || return 0
    local mime=""
    if command -v file >/dev/null 2>&1; then
        mime="$(file -b --mime-type "$f" || true)"
    fi
    case "$mime" in
        image/jpeg | image/jpg | image/png | image/webp) ;;
        *)
            return 0
            ;;
    esac
    stdbuf -oL printf 'INGEST %s\n' "$f" || printf 'INGEST %s\n' "$f"
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
    if command -v inotifywait >/dev/null 2>&1; then
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            if [ -z "${seen[$f]+x}" ]; then
                seen["$f"]=1
                notify_new "$f"
            fi
        done < <(inotifywait -m -e close_write,moved_to,create --format '%w%f' -- "$DEST" 2>/dev/null)
    else
        while true; do
            sleep 1
            while IFS= read -r -d '' f; do
                if [ -z "${seen[$f]+x}" ]; then
                    seen["$f"]=1
                    notify_new "$f"
                fi
            done < <(find "$DEST" -maxdepth 1 -type f -print0 2>/dev/null || true)
        done
    fi
) &
watch_pid=$!

"$QML" -- "$SCRIPT_DIR/wallpaper-provider.qml" "$URL" "$DEST" &
qml_pid=$!
wait "$qml_pid"
