#!/usr/bin/env bash
# A window keeps the cursor image it already set, so changing the theme
# only shows the watch on surfaces that ask again (the dock). Hyprland
# can hold one shape above those images. That is the global pointer.
# The theme swap below is the fallback when that plugin cannot load.
# XCURSOR_THEME is left alone so the new process still starts with the arrow.
set -euo pipefail

busy_name=modern-cursor-busy
timeout_s="${MODERN_CURSOR_BUSY_TIMEOUT:-60}"

runtime_dir() {
    printf '%s\n' "${MODERN_CURSOR_BUSY_RUNTIME:-${XDG_RUNTIME_DIR:-/tmp}/modern-cursor-busy}"
}

icon_root() {
    if [[ -n "${MODERN_CURSOR_ICON_ROOT:-}" ]]; then
        printf '%s\n' "$MODERN_CURSOR_ICON_ROOT"
        return
    fi
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/icons"
}

read_theme() {
    if [[ -n "${MODERN_CURSOR_THEME:-}" ]]; then
        theme=$MODERN_CURSOR_THEME
        size=${MODERN_CURSOR_SIZE:-24}
    else
        local cfg="${MODERN_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"
        theme=Bibata-Modern-Classic
        size=24
        if [[ -r "$cfg" ]] && command -v jq >/dev/null 2>&1; then
            theme=$(jq -r '.design.cursorTheme // "Bibata-Modern-Classic"' "$cfg")
            size=$(jq -r '.design.cursorSize // 24' "$cfg")
        fi
    fi
    if [[ -z "$theme" || "$theme" == "null" ]]; then
        theme=Bibata-Modern-Classic
    fi
    if ! [[ "$size" =~ ^[0-9]+$ ]] || [[ "$size" -lt 1 ]]; then
        size=24
    fi
}

find_theme_dir() {
    local name="$1" dir extra
    local dirs=()
    dirs+=("${XDG_DATA_HOME:-$HOME/.local/share}/icons")
    dirs+=("$HOME/.icons")
    local IFS=:
    # shellcheck disable=SC2086
    for extra in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
        dirs+=("$extra/icons")
    done
    unset IFS
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir/$name/cursors" ]]; then
            printf '%s\n' "$dir/$name"
            return 0
        fi
    done
    return 1
}

install_busy_theme() {
    local src="$1" dest="$2" watch="" f base
    if [[ -e "$src/cursors/left_ptr_watch" ]]; then
        watch=$(readlink -f "$src/cursors/left_ptr_watch")
    elif [[ -e "$src/cursors/progress" ]]; then
        watch=$(readlink -f "$src/cursors/progress")
    elif [[ -e "$src/cursors/wait" ]]; then
        watch=$(readlink -f "$src/cursors/wait")
    fi
    if [[ -z "$watch" || ! -f "$watch" ]]; then
        return 1
    fi
    # dest is always .../modern-cursor-busy, never a theme we were given.
    [[ "$dest" == */modern-cursor-busy ]] || return 1
    rm -rf -- "$dest"
    mkdir -p "$dest/cursors"
    for f in "$src/cursors"/*; do
        [[ -e "$f" ]] || continue
        base=$(basename "$f")
        ln -s "$(readlink -f "$f")" "$dest/cursors/$base"
    done
    # Clients ask for "default"; the desktop asks for left_ptr.
    ln -sfn "$watch" "$dest/cursors/left_ptr"
    ln -sfn "$watch" "$dest/cursors/default"
    ln -sfn "$watch" "$dest/cursors/arrow"
    printf '[Icon Theme]\nName=%s\nComment=Pointer while a program is opening\nInherits=%s\n' \
        "$busy_name" "$theme" >"$dest/index.theme"
}

apply_cursor() {
    local name="$1" px="$2"
    if [[ "${MODERN_CURSOR_BUSY_DRY:-}" == 1 ]]; then
        printf 'setcursor %s %s\n' "$name" "$px"
        return 0
    fi
    command -v hyprctl >/dev/null 2>&1 || return 1
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 1
    hyprctl setcursor "$name" "$px" >/dev/null
}

script_dir() {
    (cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
}

watch_shape() {
    local src="$1"
    if [[ -e "$src/cursors/left_ptr_watch" ]]; then
        printf '%s\n' left_ptr_watch
    elif [[ -e "$src/cursors/progress" ]]; then
        printf '%s\n' progress
    elif [[ -e "$src/cursors/wait" ]]; then
        printf '%s\n' wait
    else
        return 1
    fi
}

# Compiled against this Hyprland. A packaged copy from another build
# would not match the compositor and must not be loaded.
compile_plugin() {
    local so="$1" src stamp ver cflags
    src="$(script_dir)/hypr-cursor-busy.cpp"
    [[ -f "$src" ]] || return 1
    command -v g++ >/dev/null 2>&1 || return 1
    command -v pkg-config >/dev/null 2>&1 || return 1
    [[ -f /usr/include/hyprland/src/plugins/PluginAPI.hpp ]] || return 1
    ver=$(hyprctl version 2>/dev/null | head -n 1 || true)
    [[ -n "$ver" ]] || return 1
    stamp="$(runtime_dir)/plugin.stamp"
    if [[ -f "$so" && -f "$stamp" && "$(<"$stamp")" == "$ver" ]]; then
        return 0
    fi
    cflags=$(pkg-config --cflags pixman-1 libdrm wayland-server hyprutils hyprlang libinput aquamarine cairo pango hyprgraphics) \
        || return 1
    mkdir -p "$(runtime_dir)"
    # pkg-config prints one line of -I flags.
    # shellcheck disable=SC2086
    g++ -shared -fPIC -std=gnu++26 -O2 \
        -I/usr/include/hyprland/src -I/usr/include/hyprland \
        $cflags "$src" -o "$so" || return 1
    printf '%s\n' "$ver" >"$stamp"
}

load_plugin() {
    local so
    so="$(runtime_dir)/cursor-busy.so"
    compile_plugin "$so" || return 1
    if hyprctl plugin list 2>/dev/null | grep -q 'modern-cursor-busy'; then
        return 0
    fi
    hyprctl plugin load "$so" >/dev/null
}

plugin_begin() {
    local shape="$1" out
    [[ "${MODERN_CURSOR_BUSY_DRY:-}" == 1 ]] && return 1
    command -v hyprctl >/dev/null 2>&1 || return 1
    load_plugin || return 1
    out=$(hyprctl cursorbusy begin "$shape" 2>/dev/null || true)
    [[ "$out" == ok ]]
}

plugin_end() {
    [[ "${MODERN_CURSOR_BUSY_DRY:-}" == 1 ]] && return 0
    command -v hyprctl >/dev/null 2>&1 || return 0
    hyprctl cursorbusy end >/dev/null 2>&1 || true
}

# The shell's own surfaces keep a cursor pixmap. Tell them to show the
# watch too; a missing shell must not cancel the compositor cursor.
shell_busy() {
    [[ "${MODERN_CURSOR_BUSY_DRY:-}" == 1 ]] && return 0
    command -v qs >/dev/null 2>&1 || return 0
    qs -c modern ipc call launchcursor "$1" >/dev/null 2>&1 || true
}

cmd_restore() {
    local rt theme_now size_now gen=""
    rt=$(runtime_dir)
    [[ -r "$rt/theme" && -r "$rt/size" ]] || return 0
    theme_now=$(<"$rt/theme")
    size_now=$(<"$rt/size")
    if [[ -n "${1:-}" ]]; then
        [[ -r "$rt/gen" ]] || return 0
        gen=$(<"$rt/gen")
        [[ "$gen" == "$1" ]] || return 0
    fi
    if [[ -r "$rt/mode" && "$(<"$rt/mode")" == override ]]; then
        plugin_end
    else
        apply_cursor "$theme_now" "$size_now" || true
    fi
    shell_busy end
    rm -f -- "$rt/gen" "$rt/mode"
}

cmd_watch() {
    local gen="${1:-}" rt sock status=0
    [[ -n "$gen" ]] || return 0
    rt=$(runtime_dir)
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        cmd_restore "$gen"
        return 0
    fi
    sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
    if [[ ! -S "$sock" ]]; then
        cmd_restore "$gen"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        cmd_restore "$gen"
        return 0
    fi
    set +e
    MODERN_HYPR_SOCKET="$sock" \
        MODERN_CURSOR_GEN_FILE="$rt/gen" \
        MODERN_CURSOR_GEN="$gen" \
        MODERN_CURSOR_BUSY_TIMEOUT="$timeout_s" \
        python3 - <<'PY'
import os, select, socket, time

gen_file = os.environ["MODERN_CURSOR_GEN_FILE"]
gen = os.environ["MODERN_CURSOR_GEN"]
deadline = time.monotonic() + float(os.environ.get("MODERN_CURSOR_BUSY_TIMEOUT", "60"))
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(os.environ["MODERN_HYPR_SOCKET"])
sock.setblocking(False)
buf = ""

def current():
    try:
        with open(gen_file, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return ""

while time.monotonic() < deadline:
    if current() != gen:
        raise SystemExit(0)
    ready, _, _ = select.select([sock], [], [], 0.2)
    if not ready:
        continue
    chunk = sock.recv(65536)
    if not chunk:
        break
    buf += chunk.decode("utf-8", "replace")
    while "\n" in buf:
        line, buf = buf.split("\n", 1)
        # A focus change is not the program opening. Steam (and most
        # launchers) move focus before any window exists; ending there
        # put the arrow back while the app was still starting.
        if line.startswith("openwindow>>"):
            raise SystemExit(2)
raise SystemExit(2)
PY
    status=$?
    set -e
    # 0 means a newer launch owns the pointer. Anything else puts the
    # arrow back, including a crash so the watch cannot stick.
    if [[ "$status" -ne 0 ]]; then
        cmd_restore "$gen"
    fi
}

cmd_start() {
    local src dest root rt gen addr="" shape=""
    read_theme
    if [[ -n "${MODERN_CURSOR_THEME_DIR:-}" ]]; then
        src=$MODERN_CURSOR_THEME_DIR
    else
        src=$(find_theme_dir "$theme") || return 0
    fi
    [[ -d "$src/cursors" ]] || return 0
    shape=$(watch_shape "$src" || true)
    rt=$(runtime_dir)
    mkdir -p "$rt"
    printf '%s\n' "$theme" >"$rt/theme"
    printf '%s\n' "$size" >"$rt/size"
    gen=$(od -An -N8 -tu8 /dev/urandom | tr -d '[:space:]')
    printf '%s\n' "$gen" >"$rt/gen"
    if [[ -n "$shape" ]] && plugin_begin "$shape"; then
        printf 'override\n' >"$rt/mode"
        shell_busy begin
        setsid "$0" watch "$gen" </dev/null >/dev/null 2>&1 &
        return 0
    fi
    root=$(icon_root)
    dest="$root/$busy_name"
    install_busy_theme "$src" "$dest" || return 0
    printf 'theme\n' >"$rt/mode"
    if [[ "${MODERN_CURSOR_BUSY_DRY:-}" != 1 ]] && command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // ""' 2>/dev/null || true)
    fi
    printf '%s\n' "$addr" >"$rt/address"
    apply_cursor "$busy_name" "$size" || return 0
    shell_busy begin
    if [[ "${MODERN_CURSOR_BUSY_DRY:-}" == 1 ]]; then
        return 0
    fi
    setsid "$0" watch "$gen" </dev/null >/dev/null 2>&1 &
    # The click that started the program sets the arrow again after a
    # theme swap. Put the watch back once that settles, if this launch
    # still owns it. The override path ignores those client cursors.
    (
        sleep 0.3
        [[ "$(cat "$rt/gen" 2>/dev/null || true)" == "$gen" ]] || exit 0
        apply_cursor "$busy_name" "$size" || true
        shell_busy begin
    ) </dev/null >/dev/null 2>&1 &
}

case "${1:-}" in
    start) cmd_start ;;
    watch) cmd_watch "${2:-}" ;;
    restore) cmd_restore ;;
    *)
        echo "usage: cursor-busy.sh start|watch GEN|restore" >&2
        exit 2
        ;;
esac
