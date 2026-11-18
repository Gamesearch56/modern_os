#!/usr/bin/env bash
# Wallpaper path + size + mtime, scoped to this matugen build.
# A new file still goes through image scoring; a file already scored
# does not. theme-apply.sh and theme-previews.sh share the file so a
# light/dark switch does not decode the image again.
# Caller sets STATE_DIR. THEME_SEED_VERSION overrides the matugen
# version for tests.

theme_matugen_version() {
    if [ -n "${THEME_SEED_VERSION:-}" ]; then
        printf '%s\n' "$THEME_SEED_VERSION"
        return 0
    fi
    matugen --version 2>/dev/null | awk '{print $2}'
}

theme_seed_cache() {
    printf '%s\n' "$STATE_DIR/theme-image-seeds.json"
}

theme_cached_seed() {
    local path="$1" sig ver cache
    cache="$(theme_seed_cache)"
    [ -f "$cache" ] || return 1
    sig="$(stat -c '%s:%Y' "$path")"
    ver="$(theme_matugen_version)"
    [ -n "$ver" ] || return 1
    jq -er --arg p "$path" --arg s "$sig" --arg v "$ver" \
        'select(.matugen == $v) | .images[$p] | select(.sig == $s) | .seed' \
        "$cache"
}

theme_store_seed() {
    local path="$1" seed="$2" sig ver cache tmp
    cache="$(theme_seed_cache)"
    sig="$(stat -c '%s:%Y' "$path")"
    ver="$(theme_matugen_version)"
    [ -n "$ver" ] && [ -n "$seed" ] || return 0
    mkdir -p "$STATE_DIR"
    tmp="$(mktemp "${STATE_DIR}/theme-image-seeds.XXXXXX")"
    if [ -f "$cache" ]; then
        jq --arg p "$path" --arg s "$sig" --arg c "$seed" --arg v "$ver" \
            '.matugen = $v | .images[$p] = {sig:$s, seed:$c}' \
            "$cache" >"$tmp" || { rm -f "$tmp"; return 0; }
    else
        jq -n --arg p "$path" --arg s "$sig" --arg c "$seed" --arg v "$ver" \
            '{matugen:$v, images:{($p): {sig:$s, seed:$c}}}' >"$tmp" \
            || { rm -f "$tmp"; return 0; }
    fi
    mv -f "$tmp" "$cache"
}
