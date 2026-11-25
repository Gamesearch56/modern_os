#!/usr/bin/env bash
# Print `path<TAB>thumb` as each wallpaper tile JPEG is ready. Existing
# cache hits are emitted first so QML can swap sources before magick
# runs. Qt still full-decodes many originals even with sourceSize set;
# these 512px JPEGs are what the picker and Settings gallery actually
# paint.
set -euo pipefail

if [ "${_MODERN_THUMBS_STDBUF:-}" != "1" ] && command -v stdbuf >/dev/null 2>&1; then
    export _MODERN_THUMBS_STDBUF=1
    exec stdbuf -oL bash "$0" "$@"
fi

# shellcheck source=lib/wallpaper-thumb.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/wallpaper-thumb.sh"

emit() {
    printf '%s\t%s\n' "$1" "$2"
}

if [ "$#" -eq 0 ]; then
    exit 0
fi

pending=()
for src in "$@"; do
    [ -f "$src" ] || continue
    dest="$(wallpaper_thumb_path "$src")" || continue
    if [ -f "$dest" ]; then
        emit "$src" "$dest"
    else
        pending+=("$src")
    fi
done

if [ "${#pending[@]}" -eq 0 ]; then
    exit 0
fi

jobs_max="$(nproc 2>/dev/null || echo 4)"
if [ "$jobs_max" -gt 4 ]; then
    jobs_max=4
fi
if [ "$jobs_max" -lt 1 ]; then
    jobs_max=1
fi

running=0
for src in "${pending[@]}"; do
    (
        dest="$(wallpaper_thumb_path "$src")" || exit 0
        if [ -f "$dest" ] || wallpaper_thumb_make "$src" "$dest"; then
            emit "$src" "$dest"
        fi
    ) &
    running=$((running + 1))
    if [ "$running" -ge "$jobs_max" ]; then
        wait -n || true
        running=$((running - 1))
    fi
done
wait || true
