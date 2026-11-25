#!/usr/bin/env bash
# Install the ollama package from the official repos. No arguments, so
# this cannot be pointed at another package. The password dialog is
# pkexec; the polkit agent is started first so it does not fall back
# to a terminal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/polkit-agent.sh
source "$ROOT/lib/polkit-agent.sh"

if [ "$#" -ne 0 ]; then
    printf 'usage: ollama-install.sh\n' >&2
    exit 2
fi

if [ "${OLLAMA_INSTALL_DRY:-}" = "1" ]; then
    printf '%s\n' 'pacman -S --noconfirm --needed -- ollama'
    exit 0
fi

PACMAN="/usr/bin/pacman"
PKEXEC="/usr/bin/pkexec"
if [ ! -x "$PACMAN" ] || [ ! -x "$PKEXEC" ]; then
    printf 'ollama-install: pacman or pkexec is missing\n' >&2
    exit 1
fi
if ! ensure_polkit_agent; then
    printf 'ollama-install: password dialog is not available\n' >&2
    exit 6
fi
if "$PACMAN" -Q -- ollama >/dev/null 2>&1; then
    exit 0
fi
if ! "$PACMAN" -Si -- ollama >/dev/null 2>&1; then
    printf 'ollama-install: ollama is not in the official repositories\n' >&2
    exit 3
fi
exec "$PKEXEC" "$PACMAN" -S --noconfirm --needed -- ollama
