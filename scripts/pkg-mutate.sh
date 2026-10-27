#!/usr/bin/env bash
# Install or remove one official-repo package. Hardcoded pkexec + pacman
# argv only — never PACMAN= from the environment, never a shell.
# Preflight is unprivileged; the transaction is the only pkexec step.
# Do not SIGKILL this process: a live pacman transaction is unsafe to abort.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"
# shellcheck source=lib/polkit-agent.sh
source "$ROOT/lib/polkit-agent.sh"

if [ "$#" -ne 2 ]; then
    printf 'usage: pkg-mutate.sh install|remove <name>\n' >&2
    exit 2
fi

action="$1"
name="$2"
PACMAN="/usr/bin/pacman"
PKEXEC="/usr/bin/pkexec"

if [ "$action" != "install" ] && [ "$action" != "remove" ]; then
    printf 'usage: pkg-mutate.sh install|remove <name>\n' >&2
    exit 2
fi
if ! valid_pkg_name "$name"; then
    printf 'invalid package name\n' >&2
    exit 2
fi
if [ ! -x "$PACMAN" ]; then
    printf 'pacman missing\n' >&2
    exit 1
fi
if [ ! -x "$PKEXEC" ]; then
    printf 'pkexec missing\n' >&2
    exit 1
fi
if ! ensure_polkit_agent; then
    printf 'polkit agent is not running\n' >&2
    exit 6
fi

export LC_ALL=C

if [ "$action" = "install" ]; then
    if ! "$PACMAN" -Si -- "$name" >/dev/null 2>&1; then
        printf 'package not in official repositories: %s\n' "$name" >&2
        exit 3
    fi
    exec "$PKEXEC" "$PACMAN" -S --noconfirm --needed -- "$name"
fi

if protected_pkg "$name" \
    || "$ROOT/pkg-manifest-names.sh" --core | jq -e --arg n "$name" 'index($n) != null' >/dev/null 2>&1; then
    printf 'refusing to remove protected package: %s\n' "$name" >&2
    exit 5
fi
if ! "$PACMAN" -Q -- "$name" >/dev/null 2>&1; then
    printf 'package is not installed: %s\n' "$name" >&2
    exit 4
fi
# Named package only — no -s/-n, so unused deps and pacsave stay.
exec "$PKEXEC" "$PACMAN" -R --noconfirm -- "$name"
