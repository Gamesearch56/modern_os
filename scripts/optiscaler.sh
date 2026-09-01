#!/usr/bin/env bash
# Fetch, list, apply and remove OptiScaler into a game directory.
# Apply never deletes the game's own dxgi.dll (or other proxy): it copies
# the original aside into .modern-optiscaler-backup/ first, because many
# titles ship a real DXGI/D3D12 loader under that name. `remove` restores
# the backup so the game is playable without OptiScaler again.
#
# Usage:
#   optiscaler.sh fetch
#   optiscaler.sh list
#   optiscaler.sh apply GAME_DIR [proxy]
#   optiscaler.sh remove GAME_DIR
#   optiscaler.sh games
#
# Requires: curl, jq. Optional: 7z or unzip to extract the release.
set -euo pipefail

REPO="OptiScaler-Releases/OptiScaler"
API="https://api.github.com/repos/${REPO}/releases/latest"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/modern/optiscaler"
BACKUP_NAME=".modern-optiscaler-backup"
STEAM_VDF="${HOME}/.steam/steam/steamapps/libraryfolders.vdf"

die() { printf 'optiscaler: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'optiscaler: %s\n' "$*"; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing dependency '$1' (install it and retry)"
}

usage() {
    grep '^#' "$0" | cut -c3- | head -n 16
}

latest_tag_dir() {
    local d
    d="$(find "$SHARE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V | tail -n1 || true)"
    [ -n "$d" ] || die "no fetched release — run: $0 fetch"
    printf '%s/%s\n' "$SHARE" "$d"
}

cmd_fetch() {
    need curl
    need jq
    mkdir -p "$SHARE"
    log "querying GitHub API for latest ${REPO} release..."
    local json tag url name dest
    if ! json="$(curl -fsSL --max-time 30 -A "modern-dotfile-optiscaler" "$API")"; then
        die "network failed talking to GitHub API (${API}). Check connectivity and retry."
    fi
    tag="$(printf '%s' "$json" | jq -r '.tag_name // empty')"
    if [ -z "$tag" ] || [ "$tag" = "null" ]; then
        die "GitHub API returned no tag_name"
    fi
    url="$(printf '%s' "$json" | jq -r '.assets[]? | select(.name | test("\\.(7z|zip)$")) | .browser_download_url' | head -n1)"
    name="$(printf '%s' "$json" | jq -r '.assets[]? | select(.name | test("\\.(7z|zip)$")) | .name' | head -n1)"
    [ -n "$url" ] || die "no .7z/.zip asset on release ${tag}"
    dest="${SHARE}/${tag}"
    mkdir -p "$dest"
    log "downloading ${name} → ${dest}/"
    if ! curl -fL --max-time 120 -o "${dest}/${name}" "$url"; then
        rm -f "${dest}/${name}"
        die "network failed downloading ${url}"
    fi
    printf '%s\n' "$tag" > "${dest}/TAG"
    log "fetched ${tag}"
}

cmd_list() {
    if [ ! -d "$SHARE" ]; then
        log "nothing fetched yet (run: $0 fetch)"
        return 0
    fi
    find "$SHARE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V
}

extract_if_needed() {
    local dir="$1"
    if find "$dir" -iname 'OptiScaler.dll' -print -quit | grep -q .; then
        return 0
    fi
    local archive
    archive="$(find "$dir" -maxdepth 1 \( -name '*.7z' -o -name '*.zip' \) | head -n1)"
    [ -n "$archive" ] || die "no archive and no OptiScaler.dll in ${dir}"
    case "$archive" in
        *.7z)
            command -v 7z >/dev/null 2>&1 || die "need 7z to extract ${archive}"
            7z x -y -o"$dir" "$archive" >/dev/null
            ;;
        *.zip)
            command -v unzip >/dev/null 2>&1 || die "need unzip to extract ${archive}"
            unzip -qo "$archive" -d "$dir"
            ;;
    esac
}

cmd_apply() {
    local game_dir="${1:-}"
    local proxy="${2:-dxgi}"
    [ -n "$game_dir" ] || die "usage: $0 apply GAME_DIR [proxy]"
    [ -d "$game_dir" ] || die "GAME_DIR is not a directory: ${game_dir}"
    proxy="${proxy%.dll}"
    local src dll dest backup
    src="$(latest_tag_dir)"
    extract_if_needed "$src"
    dll="$(find "$src" -iname 'OptiScaler.dll' | head -n1)"
    [ -n "$dll" ] || die "OptiScaler.dll not found under ${src}"
    dest="${game_dir}/${proxy}.dll"
    backup="${game_dir}/${BACKUP_NAME}"
    mkdir -p "$backup"
    # Why this backup exists: titles often ship their own dxgi.dll (or
    # winmm/version/...). Overwriting without a copy would make `remove`
    # unable to restore a working game — we must not delete the original.
    if [ -e "$dest" ] && [ ! -e "${backup}/${proxy}.dll" ]; then
        cp -a "$dest" "${backup}/${proxy}.dll"
        log "backed up existing ${proxy}.dll → ${backup}/"
    fi
    cp -a "$dll" "$dest"
    local ini
    ini="$(find "$src" -iname 'OptiScaler.ini' | head -n1 || true)"
    if [ -n "$ini" ]; then
        if [ -e "${game_dir}/OptiScaler.ini" ] && [ ! -e "${backup}/OptiScaler.ini" ]; then
            cp -a "${game_dir}/OptiScaler.ini" "${backup}/OptiScaler.ini"
        fi
        cp -a "$ini" "${game_dir}/OptiScaler.ini"
    fi
    printf '%s\n' "$proxy" > "${backup}/proxy"
    log "applied OptiScaler as ${proxy}.dll in ${game_dir}"
}

cmd_remove() {
    local game_dir="${1:-}"
    [ -n "$game_dir" ] || die "usage: $0 remove GAME_DIR"
    [ -d "$game_dir" ] || die "GAME_DIR is not a directory: ${game_dir}"
    local backup="${game_dir}/${BACKUP_NAME}"
    [ -d "$backup" ] || die "no ${BACKUP_NAME}/ in ${game_dir} — nothing to restore"
    local proxy="dxgi"
    [ -f "${backup}/proxy" ] && proxy="$(cat "${backup}/proxy")"
    if [ -e "${backup}/${proxy}.dll" ]; then
        cp -a "${backup}/${proxy}.dll" "${game_dir}/${proxy}.dll"
        log "restored ${proxy}.dll from backup"
    else
        # No original existed — drop the proxy we installed, do not leave
        # a dangling OptiScaler dxgi.dll that the game never shipped.
        rm -f "${game_dir}/${proxy}.dll"
        log "removed installed ${proxy}.dll (game had no original)"
    fi
    if [ -e "${backup}/OptiScaler.ini" ]; then
        cp -a "${backup}/OptiScaler.ini" "${game_dir}/OptiScaler.ini"
    fi
    log "remove complete (backup kept at ${backup})"
}

cmd_games() {
    if [ ! -f "$STEAM_VDF" ]; then
        log "no Steam library file at ${STEAM_VDF}"
        return 0
    fi
    local path common
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        common="${path}/steamapps/common"
        [ -d "$common" ] || continue
        find "$common" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null
    done < <(awk -F'"' '/"path"/{print $4}' "$STEAM_VDF")
}

cmd="${1:-}"
shift || true
case "$cmd" in
    fetch) cmd_fetch ;;
    list) cmd_list ;;
    apply) cmd_apply "${1:-}" "${2:-dxgi}" ;;
    remove) cmd_remove "${1:-}" ;;
    games) cmd_games ;;
    -h|--help|"") usage ;;
    *) die "unknown subcommand '${cmd}' (try --help)" ;;
esac
