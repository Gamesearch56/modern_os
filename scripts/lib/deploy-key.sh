#!/usr/bin/env bash
# Read-only GitHub deploy key. An image built for download does not embed one.
# Source, never execute. The private half stays gitignored
# (secrets/github-deploy-key on the build machine,
# ~/.config/modern/deploy_key on an installed system). This file only
# decides whether it is safe to use and builds the ssh command.
# The repo address is fixed: a key file cannot point git anywhere else.

GITHUB_HTTPS_URL="https://github.com/Gamesearch56/modern_os.git"
GITHUB_SSH_URL="git@github.com:Gamesearch56/modern_os.git"

_deploy_key_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OpenSSH private key, not a symlink, and unreadable to group and other.
# Does not check the owner; callers do, because iso-build also runs as root.
deploy_key_private() {
    local file="$1" mode
    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    mode="$(stat -c '%a' "$file" 2>/dev/null || true)"
    case "$mode" in
        [0-7]00) ;;
        *) return 1 ;;
    esac
    [ "$(head -n 1 "$file" 2>/dev/null || true)" = "-----BEGIN OPENSSH PRIVATE KEY-----" ]
}

deploy_key_owner_ok() {
    local file="$1" uid
    uid="$(stat -c '%u' "$file")"
    if [ "$(id -u)" -ne 0 ]; then
        [ "$uid" = "$(id -u)" ]
        return
    fi
    # sudo iso-build.sh: the key belongs to the user who invoked sudo.
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
        [ "$uid" = "$(id -u "$SUDO_USER")" ]
        return
    fi
    [ "$uid" = 0 ]
}

deploy_key_usable() {
    deploy_key_private "$1" && deploy_key_owner_ok "$1"
}

# Installed systems keep the key in the user config. The build machine
# keeps it in the checkout, which is gitignored. Tests pass one path
# and must not see either of those.
deploy_key_candidates() {
    if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
        [ -n "${MODERN_DEPLOY_KEY:-}" ] && printf '%s\n' "$MODERN_DEPLOY_KEY"
        return 0
    fi
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/modern/deploy_key"
    if [ -n "${MODERN_REPO_ROOT:-}" ]; then
        printf '%s\n' "$MODERN_REPO_ROOT/secrets/github-deploy-key"
    fi
}

deploy_key_file() {
    local candidate
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if deploy_key_usable "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(deploy_key_candidates)
}

github_sync_url() {
    if [ -n "$(deploy_key_file)" ]; then
        printf '%s\n' "$GITHUB_SSH_URL"
    else
        printf '%s\n' "$GITHUB_HTTPS_URL"
    fi
}

github_web_url() {
    printf '%s\n' "${GITHUB_HTTPS_URL%.git}"
}

# Empty when no usable key. Fails when a key exists but the pinned
# GitHub host keys (next to this file) are missing: unverified SSH
# would accept a network attacker as GitHub.
github_ssh_command() {
    local key hosts
    key="$(deploy_key_file)"
    [ -n "$key" ] || return 0
    hosts="$_deploy_key_lib_dir/github-known-hosts"
    [ -f "$hosts" ] || return 1
    # %q so a space or quote in the path cannot become another ssh argument.
    # -F /dev/null ignores ~/.ssh/config. IdentitiesOnly plus IdentityAgent
    # ignore every other key and the agent. GlobalKnownHostsFile=/dev/null
    # means a poisoned system known_hosts cannot add a second github.com key.
    printf 'ssh -F /dev/null -o IdentitiesOnly=yes -o IdentityAgent=none -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=15 -i %q -o UserKnownHostsFile=%q' \
        "$key" "$hosts"
}

# Copy the build machine's key into the ISO work tree. Missing is fine
# (updates stay on HTTPS). Present but unsafe is an error.
stage_deploy_key() {
    local dest="$1"
    local src="${2:-${MODERN_REPO_ROOT:-}/secrets/github-deploy-key}"
    [ -e "$src" ] || [ -L "$src" ] || return 0
    if [ -L "$src" ] || ! deploy_key_usable "$src"; then
        printf 'deploy-key: %s must be an OpenSSH private key owned by you, mode 600, not a symlink\n' \
            "$src" >&2
        return 1
    fi
    install -m 0600 "$src" "$dest"
}
