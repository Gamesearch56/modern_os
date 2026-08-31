#!/usr/bin/env bash
# Wallpaper provider site in its own Qt WebEngine process.
# Embedding WebEngineView in Quickshell aborts: Chromium needs argv[0]
# on QCoreApplication, and the shell starts without one.
set -euo pipefail

URL="${1:-}"
DEST="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

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

theme_json() {
    local tokens="$CONFIG_HOME/modern/tokens.json"
    local fallback='{"color":{"primary":"#74d7ca","onSurface":"#ebdfe9","onSurfaceVariant":"#d2c2d2","surface":"#171118","surfaceContainer":"#241d25","outlineVariant":"#4e4350","error":"#ffb4ab"},"spacing":{"xs":4,"sm":8,"md":12,"lg":16,"xl":24,"xxl":32},"radius":{"full":9999},"icon":{"md":24},"stroke":{"hairline":1},"interaction":{"hover":0.08,"press":0.12}}'
    if command -v jq >/dev/null 2>&1 && [ -f "$tokens" ]; then
        jq -c '{
            color: {
                primary: (.color.primary // "#74d7ca"),
                onSurface: (.color.onSurface // "#ebdfe9"),
                onSurfaceVariant: (.color.onSurfaceVariant // "#d2c2d2"),
                surface: (.color.surface // "#171118"),
                surfaceContainer: (.color.surfaceContainer // "#241d25"),
                outlineVariant: (.color.outlineVariant // "#4e4350"),
                error: (.color.error // "#ffb4ab")
            },
            spacing: {xs:4, sm:8, md:12, lg:16, xl:24, xxl:32},
            radius: {full:9999},
            icon: {md:24},
            stroke: {hairline:1},
            interaction: {hover:0.08, press:0.12}
        }' "$tokens" 2>/dev/null || printf '%s\n' "$fallback"
    else
        printf '%s\n' "$fallback"
    fi
}

i18n_json() {
    local cfg="$CONFIG_HOME/modern/config.json"
    local lang="en"
    if command -v jq >/dev/null 2>&1 && [ -f "$cfg" ]; then
        lang="$(jq -r '.language.ui // "en"' "$cfg" 2>/dev/null || printf 'en')"
    fi
    case "$lang" in
        de | en) ;;
        *) lang="en" ;;
    esac
    local trans="$CONFIG_HOME/modern/translations/${lang}.json"
    local back="Back"
    local forward="Forward"
    local close="Close"
    if command -v jq >/dev/null 2>&1 && [ -f "$trans" ]; then
        back="$(jq -r '.wallpaper.providerBack // "Back"' "$trans" 2>/dev/null || printf 'Back')"
        forward="$(jq -r '.wallpaper.providerForward // "Forward"' "$trans" 2>/dev/null || printf 'Forward')"
        close="$(jq -r '.bar.close // "Close"' "$trans" 2>/dev/null || printf 'Close')"
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg back "$back" --arg forward "$forward" --arg close "$close" \
            '{back:$back,forward:$forward,close:$close}'
    else
        printf '{"back":"Back","forward":"Forward","close":"Close"}\n'
    fi
}

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
proxy_pid=""
proxy_fd=""

cleanup() {
    if [ -n "${watch_pid:-}" ]; then
        kill "$watch_pid" 2>/dev/null || true
    fi
    if [ -n "${qml_pid:-}" ]; then
        kill "$qml_pid" 2>/dev/null || true
        wait "$qml_pid" 2>/dev/null || true
    fi
    if [ -n "${proxy_pid:-}" ]; then
        kill "$proxy_pid" 2>/dev/null || true
        wait "$proxy_pid" 2>/dev/null || true
    fi
    if [ -n "${proxy_fd:-}" ]; then
        exec {proxy_fd}<&- || true
    fi
}
trap cleanup EXIT TERM INT

start_filter_proxy() {
    local py="$SCRIPT_DIR/lib/web-filter-proxy.py"
    local hosts="$SCRIPT_DIR/lib/web-filter-hosts.txt"
    local line=""
    local port=""
    if ! command -v python3 >/dev/null 2>&1; then
        return 0
    fi
    if [ ! -f "$py" ] || [ ! -f "$hosts" ]; then
        return 0
    fi
    export PYTHONUNBUFFERED=1
    exec {proxy_fd}< <(python3 "$py" --hosts "$hosts")
    proxy_pid=$!
    if IFS= read -r -t 2 line <&"$proxy_fd"; then
        case "$line" in
            PORT\ *) port="${line#PORT }" ;;
        esac
    fi
    if [ -z "$port" ]; then
        kill "$proxy_pid" 2>/dev/null || true
        proxy_pid=""
        return 0
    fi
    local flags="${QTWEBENGINE_CHROMIUM_FLAGS:-}"
    flags="${flags:+$flags }--proxy-server=http://127.0.0.1:${port} --proxy-bypass-list=<-loopback>"
    export QTWEBENGINE_CHROMIUM_FLAGS="$flags"
}

start_filter_proxy

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

"$QML" -f "$SCRIPT_DIR/wallpaper-provider.qml" -- "$URL" "$DEST" "$(theme_json)" "$(i18n_json)" &
qml_pid=$!
wait "$qml_pid"
