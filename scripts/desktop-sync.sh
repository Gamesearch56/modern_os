#!/usr/bin/env bash
# Compare / apply ModernOS release tags. Settings never runs git itself.
# Production fetch is the allowlisted repo only: SSH with the read-only
# deploy key when one is installed, HTTPS otherwise. Tests may set
# MODERN_TEST_FIXTURE=1 and MODERN_DESKTOP_REMOTE to a local bare repo.
set -euo pipefail

TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Checkout that holds the gitignored build-machine key. The installed
# clone has no secrets/ directory; it uses ~/.config/modern/deploy_key.
MODERN_REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/repo-path.sh
source "$SCRIPT_DIR/lib/repo-path.sh"
# shellcheck source=lib/deploy-key.sh
source "$SCRIPT_DIR/lib/deploy-key.sh"
# shellcheck source=lib/hypr-watch.sh
source "$SCRIPT_DIR/lib/hypr-watch.sh"
REPO="${MODERN_DESKTOP_REPO:-$(modern_repo_path)}"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/modern-desktop-sync.lock"

die() { printf 'desktop-sync: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'desktop-sync: %s\n' "$*"; }

remote_url() {
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ -n "${MODERN_DESKTOP_REMOTE:-}" ]; then
        printf '%s\n' "$MODERN_DESKTOP_REMOTE"
        return
    fi
    github_sync_url
}

git_safe() {
    local extra=()
    local runner=()
    local ssh_cmd=""
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
        extra=(-c protocol.file.allow=always)
    else
        extra=(-c protocol.file.allow=never)
    fi
    if [ -n "${GIT_SAFE_TIMEOUT:-}" ]; then
        runner=(timeout "$GIT_SAFE_TIMEOUT")
    fi
    ssh_cmd="$(github_ssh_command)" || die "deploy key is set but GitHub host keys are missing"
    # Fixture tests read this back. Production never writes the command.
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ -n "${MODERN_SSH_COMMAND_LOG:-}" ]; then
        printf '%s\n' "$ssh_cmd" >"$MODERN_SSH_COMMAND_LOG"
    fi
    local env_cmd=(env -u GIT_SSH -u GIT_SSH_COMMAND
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null)
    local ssh_cfg=()
    if [ -n "$ssh_cmd" ]; then
        # GIT_SSH_COMMAND outranks core.sshCommand, and an inherited value
        # would replace the command built for this key. Set both, from here.
        env_cmd+=(GIT_SSH_COMMAND="$ssh_cmd")
        ssh_cfg=(-c "core.sshCommand=$ssh_cmd")
    fi
    "${runner[@]}" "${env_cmd[@]}" \
        /usr/bin/git -c core.hooksPath=/dev/null \
        -c fetch.recurseSubmodules=false "${extra[@]}" "${ssh_cfg[@]}" "$@"
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
    local resolved owner fallback pointer
    [ -d "$REPO/.git" ] || return 1
    resolved="$(readlink -f "$REPO")"
    fallback="$(readlink -f "$HOME/modern_dotfile" 2>/dev/null || true)"
    pointer="$(readlink -f "$(modern_repo_path)" 2>/dev/null || true)"
    case "$resolved" in
        "$fallback"|"$fallback"/*|"$pointer"|"$pointer"/*) ;;
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
    # Local edits must not hide the GitHub result. Apply still refuses a
    # dirty tree; status only needs the commit and the remote tags.
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

# Installer chmod/overlay on the home release clone is not a user edit.
# Ignored files stay. Any other clone, including a dev tree, is left alone.
discard_installer_edits() {
    local resolved home_repo tag
    resolved="$(readlink -f "$REPO")"
    home_repo="$(readlink -f "$HOME/modern_dotfile" 2>/dev/null || true)"
    tag="$(installed_tag)"
    [ -n "$home_repo" ] && [ "$resolved" = "$home_repo" ] || return 0
    [[ "$tag" =~ $TAG_RE ]] || return 0
    git_safe -C "$REPO" checkout -- .
}

cmd_apply() {
    exec 9>"$LOCK"
    flock -n 9 || die "another desktop update is running"
    repo_ok || die "repo check failed"
    pause_hypr_config_watch
    trap resume_hypr_config_watch EXIT
    discard_installer_edits
    local dirt
    dirt="$(git_safe -C "$REPO" status --porcelain)"
    if [ -n "$dirt" ]; then
        die "work tree is dirty: $(printf '%s' "$dirt" | tr '\n' '; ')"
    fi
    local latest
    latest="$(highest_tag)"
    [[ "$latest" =~ $TAG_RE ]] || die "no valid release tag"
    local url
    url="$(remote_url)"
    # Into refs/tags, not a private ref: without the local tag the next release is never offered.
    git_safe -C "$REPO" fetch --no-tags --no-recurse-submodules \
        "$url" "+refs/tags/${latest}:refs/tags/${latest}"
    git_safe -C "$REPO" merge --ff-only "refs/tags/${latest}"
    log "updated to ${latest}"
    # Fixture releases may ship a fake install.sh to exercise the root plan.
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ "${MODERN_TEST_RUN_INSTALL:-}" != "1" ]; then
        log "test fixture — skipping install.sh"
        return 0
    fi
    if [ -x "$REPO/install/install.sh" ]; then
        # Settings runs this inside Quickshell. A new session keeps the
        # installer alive if that shell restarts, and skips the theme
        # rewrite that would restart it again.
        if [ -n "${MODERN_ROOT_PLAN:-}" ]; then
            export MODERN_LIVE_UPDATE=1
            setsid -w "$REPO/install/install.sh" --profile m0 --yes
        else
            "$REPO/install/install.sh" --profile m0 --yes
        fi
    fi
}

case "${1:-}" in
    status) cmd_status ;;
    apply) cmd_apply ;;
    *) die "usage: desktop-sync.sh status|apply" ;;
esac
