#!/usr/bin/env bash
# Shipped text editor, image viewer, and video player.
# install/manifests/default-apps.json is the list. Source this file;
# do not enable set -e here (callers already have it).
# Settings writes config.json only. An empty apps.defaults role uses
# the desktop id in this manifest. Launch overrides (the image viewer's
# exec) are data here, not a desktop-id branch in an opener.

# Desktop ids the shipped apps replaced. mime-defaults.sh drops a default
# it once pinned to one of them unless Settings still chooses it.
# shellcheck disable=SC2034
DEFAULT_APPS_RETIRED="mpv.desktop imv.desktop imv-dir.desktop org.gnome.gedit.desktop"

default_apps_manifest() {
    local root="" repo_file=""
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/install/manifests/default-apps.json" ]; then
        root="$REPO_ROOT"
    else
        root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    if [ ! -f "$root/install/manifests/default-apps.json" ]; then
        repo_file="${XDG_CONFIG_HOME:-${HOME:-}/.config}/modern/repo"
        if [ -f "$repo_file" ]; then
            IFS= read -r root <"$repo_file" || true
            root="${root//$'\r'/}"
        fi
    fi
    if [ -z "$root" ] || [ ! -f "$root/install/manifests/default-apps.json" ]; then
        return 1
    fi
    printf '%s\n' "$root/install/manifests/default-apps.json"
}

# op is roles|packages|stow|desktop|exec|window-rule. desktop, exec, and
# window-rule take the role or desktop id in $2. jq is already required
# by the installer preflight; python is not installed yet at that point.
_default_apps_py() {
    local manifest="" op="${1:-}" extra="${2:-}"
    manifest="$(default_apps_manifest)" || return 1
    if ! command -v jq >/dev/null 2>&1; then
        printf 'default-apps: jq is required\n' >&2
        return 1
    fi
    case "$op" in
        roles)
            jq -r 'to_entries[].key' "$manifest"
            ;;
        packages)
            jq -r 'def strings: if type == "array" then .[] elif type == "string" and length > 0 then . else empty end; .[] | (.packages // empty) | strings' "$manifest"
            ;;
        stow)
            jq -r 'def strings: if type == "array" then .[] elif type == "string" and length > 0 then . else empty end; .[] | (.stow // empty) | strings' "$manifest"
            ;;
        desktop)
            jq -r --arg role "$extra" '.[$role].desktop // empty | select(type == "string" and length > 0)' "$manifest"
            ;;
        window-rule)
            jq -r --arg role "$extra" '.[$role].windowRule // empty | select(type == "string" and length > 0)' "$manifest"
            ;;
        exec)
            jq -r --arg want "$extra" '
                def stem: if type != "string" then "" elif endswith(".desktop") then .[:length - 8] else . end;
                def strings: if type == "array" then .[] elif type == "string" and length > 0 then . else empty end;
                ([ to_entries[].value | select(type == "object") | . as $raw
                   | select((([ ($raw.match // empty | strings), ($raw.desktop // empty | strings) ] | map(stem) | index($want | stem)) != null))
                ] | .[0]) as $hit
                | if $hit == null then empty else ($hit.exec // empty | strings) end
            ' "$manifest"
            ;;
        *)
            return 2
            ;;
    esac
}

default_app_roles() {
    _default_apps_py roles
}

default_app_packages() {
    _default_apps_py packages
}

default_app_stow() {
    _default_apps_py stow
}

default_app_desktop() {
    _default_apps_py desktop "${1:-}"
}

# Argv (one shell word per line) for a desktop id that still uses the
# shipped app's launch override. Empty when that role has no exec.
default_app_exec_for_desktop() {
    _default_apps_py exec "${1:-}"
}

default_app_window_rule() {
    _default_apps_py window-rule "${1:-}"
}
