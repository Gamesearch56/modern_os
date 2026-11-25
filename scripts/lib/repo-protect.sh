# shellcheck shell=bash
# Immutable flag for the installed release clone only.
# A development checkout, including one sitting on a release commit,
# is never marked. Source this; scripts/repo-protect.sh is the entry
# that may ask for the password.

# The account whose ~/modern_os this is. pkexec and sudo keep the
# caller's identity in PKEXEC_UID / SUDO_UID; a fixture keeps HOME.
repo_protect_home() {
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
        printf '%s\n' "$HOME"
        return 0
    fi
    local uid="${PKEXEC_UID:-${SUDO_UID:-$(id -u)}}" home=""
    home="$(getent passwd "$uid" 2>/dev/null | cut -d: -f6 || true)"
    [ -n "$home" ] || home="$HOME"
    printf '%s\n' "$home"
}

# Same rule as desktop-sync home_release_clone: the path is ~/modern_os,
# HEAD is an exact release tag, and it is not a branch.
repo_protect_is_release() {
    local home repo home_repo tag
    home="$(repo_protect_home)"
    if [ -n "${MODERN_DESKTOP_REPO:-}" ]; then
        repo="$(readlink -f "$MODERN_DESKTOP_REPO" 2>/dev/null || true)"
    else
        repo="$(HOME="$home" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$home/.config}" modern_repo_path)"
        repo="$(readlink -f "$repo" 2>/dev/null || true)"
    fi
    home_repo="$(readlink -f "$home/modern_os" 2>/dev/null || true)"
    [ -n "$repo" ] && [ -n "$home_repo" ] && [ "$repo" = "$home_repo" ] || return 1
    tag="$(git -C "$repo" -c core.hooksPath=/dev/null describe --tags --exact-match HEAD 2>/dev/null || true)"
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    git -C "$repo" -c core.hooksPath=/dev/null symbolic-ref -q HEAD >/dev/null && return 1
    printf '%s\n' "$repo"
}

# Tells desktop-sync that a root step already cleared the flag, so it
# must not ask for the password again.
repo_protect_marker() {
    local runtime="${XDG_RUNTIME_DIR:-}"
    if [ "${MODERN_TEST_FIXTURE:-}" != "1" ] && [ "$(id -u)" -eq 0 ]; then
        local uid="${PKEXEC_UID:-${SUDO_UID:-}}"
        [ -n "$uid" ] && runtime="/run/user/$uid"
    fi
    [ -n "$runtime" ] || runtime="/run/user/$(id -u)"
    printf '%s\n' "$runtime/modern/repo-unlocked"
}

repo_protect_repo() {
    local repo
    repo="$(repo_protect_is_release)" || return 1
    printf '%s\n' "$repo"
}

# chattr -R follows symlinks out of the clone. Name each real file
# and directory instead, and never a symlink.
repo_protect_chattr() {
    local flag="$1" repo="$2" bin="${MODERN_CHATTR:-chattr}"
    [ -d "$repo" ] || return 1
    find -P "$repo" \( -type d -o -type f \) -print0 | xargs -0 -r "$bin" "$flag"
}

repo_protect_escalate() {
    [ "$(id -u)" -eq 0 ] && return 0
    [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && return 0
    local cmd=(sudo --)
    if [ ! -t 0 ]; then
        cmd=("${MODERN_PKEXEC:-pkexec}" --)
    fi
    exec "${cmd[@]}" "$0" "$@"
}

repo_protect_unlock() {
    repo_protect_escalate unlock
    local repo marker
    repo="$(repo_protect_repo)" || return 0
    repo_protect_chattr -i "$repo"
    marker="$(repo_protect_marker)"
    mkdir -p -- "$(dirname -- "$marker")"
    printf '1\n' >"$marker"
}

repo_protect_lock() {
    repo_protect_escalate lock
    local repo marker
    repo="$(repo_protect_repo)" || return 0
    marker="$(repo_protect_marker)"
    # Drop the marker before the flag. A stop in between leaves the
    # files writable and the next update can mark them again.
    rm -f -- "$marker"
    repo_protect_chattr +i "$repo"
}

# Fresh install. An update that already holds the flag skips this so
# the password is not asked a second time.
repo_protect_lock_if_release() {
    local marker
    marker="$(repo_protect_marker)"
    [ ! -f "$marker" ] || return 0
    repo_protect_is_release >/dev/null || return 0
    repo_protect_lock
}
