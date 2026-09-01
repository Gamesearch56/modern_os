#!/usr/bin/env bash
# Compare / apply ModernOS release tags. Settings never runs git itself.
# Production fetch is the allowlisted HTTPS repo only. Tests may set
# MODERN_TEST_FIXTURE=1 and MODERN_DESKTOP_REMOTE to a local bare repo.
set -euo pipefail

ALLOWED_URL="https://github.com/Gamesearch56/modern_dotfile.git"
TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
REPO="${MODERN_DESKTOP_REPO:-$HOME/modern_dotfile}"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/modern-desktop-sync.lock"

die() { printf 'desktop-sync: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'desktop-sync: %s\n' "$*"; }

remote_url() {
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ -n "${MODERN_DESKTOP_REMOTE:-}" ]; then
        printf '%s\n' "$MODERN_DESKTOP_REMOTE"
        return
    fi
    printf '%s\n' "$ALLOWED_URL"
}

git_safe() {
    local extra=()
    local runner=()
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
        extra=(-c protocol.file.allow=always)
    else
        extra=(-c protocol.file.allow=never)
    fi
    if [ -n "${GIT_SAFE_TIMEOUT:-}" ]; then
        runner=(timeout "$GIT_SAFE_TIMEOUT")
    fi
    "${runner[@]}" env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        /usr/bin/git -c core.hooksPath=/dev/null \
        -c fetch.recurseSubmodules=false "${extra[@]}" "$@"
}

json_escape() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
}

emit() {
    local pending="$1" from="$2" to="$3" reason="$4"
    printf '{"kind":"desktop","pending":%s,"from":%s,"to":%s,"reason":%s}\n' \
        "$pending" "$(json_escape "$from")" "$(json_escape "$to")" "$(json_escape "$reason")"
}

repo_ok() {
    local resolved owner
    [ -d "$REPO/.git" ] || return 1
    resolved="$(readlink -f "$REPO")"
    case "$resolved" in
        "$HOME/modern_dotfile"|"$HOME/modern_dotfile"/*) ;;
        *)
            if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
                :
            else
                return 1
            fi
            ;;
    esac
    owner="$(stat -c '%u' "$resolved" 2>/dev/null || true)"
    [ "$owner" = "$(id -u)" ] || return 1
    return 0
}

installed_tag() {
    git_safe -C "$REPO" describe --tags --exact-match HEAD 2>/dev/null || true
}

highest_tag() {
    local url name best
    url="$(remote_url)"
    best=""
    while read -r _ name; do
        name="${name#refs/tags/}"
        name="${name%'^{}'}"
        [[ "$name" =~ $TAG_RE ]] || continue
        if [ -z "$best" ]; then
            best="$name"
            continue
        fi
        if printf '%s\n%s\n' "$best" "$name" | sort -V | tail -1 | grep -qx "$name"; then
            best="$name"
        fi
    done < <(GIT_SAFE_TIMEOUT=20 git_safe ls-remote --tags "$url" 'refs/tags/v*' 2>/dev/null || true)
    printf '%s\n' "$best"
}

cmd_status() {
    if ! repo_ok; then
        emit false "" "" "unavailable"
        return 0
    fi
    if [ -n "$(git_safe -C "$REPO" status --porcelain)" ]; then
        emit false "$(installed_tag)" "" "dirty"
        return 0
    fi
    local cur latest
    cur="$(installed_tag)"
    latest="$(highest_tag)"
    if [ -z "$latest" ]; then
        emit false "${cur}" "" "offline"
        return 0
    fi
    if [ -n "$cur" ] && [ "$(printf '%s\n%s\n' "$cur" "$latest" | sort -V | tail -1)" = "$cur" ]; then
        emit false "$cur" "$latest" "current"
        return 0
    fi
    if [ -z "$cur" ]; then
        emit false "HEAD" "$latest" "notag"
        return 0
    fi
    emit true "$cur" "$latest" "behind"
}

cmd_apply() {
    exec 9>"$LOCK"
    flock -n 9 || die "another desktop update is running"
    repo_ok || die "repo check failed"
    [ -z "$(git_safe -C "$REPO" status --porcelain)" ] || die "work tree is dirty"
    local latest
    latest="$(highest_tag)"
    [[ "$latest" =~ $TAG_RE ]] || die "no valid release tag"
    local url
    url="$(remote_url)"
    git_safe -C "$REPO" fetch --no-tags --no-recurse-submodules \
        "$url" "refs/tags/${latest}:refs/modern/upstream"
    git_safe -C "$REPO" merge --ff-only refs/modern/upstream
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
        log "test fixture — skipping install.sh"
        return 0
    fi
    if [ -x "$REPO/install/install.sh" ]; then
        "$REPO/install/install.sh" --profile m0 --yes
    fi
}

case "${1:-}" in
    status) cmd_status ;;
    apply) cmd_apply ;;
    *) die "usage: desktop-sync.sh status|apply" ;;
esac
