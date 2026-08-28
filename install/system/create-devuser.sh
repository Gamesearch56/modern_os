#!/usr/bin/env bash
# GATED — system-wide account creation. Never run automatically by
# install.sh. Read docs/ISOLATION.md before running this.
#
# Creates the devuser account this whole project is developed against:
# an ordinary account with an empty (but present) $HOME. "Empty" is the
# goal, not "no $HOME" — Hyprland, Quickshell and Cursor all require a
# writable $HOME, so -m is passed and everything inside it is expected to
# come from `install.sh` stowing this repo, never from a skeleton copy of
# an existing user's config.
#
# Usage: sudo install/system/create-devuser.sh [username]
#   username defaults to "devuser".
#
# Rollback: sudo userdel -r <username>
set -euo pipefail

USERNAME="${1:-devuser}"
GROUPS="wheel,video,input,audio,render,seat"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 [username]" >&2
    exit 1
fi

if id "$USERNAME" >/dev/null 2>&1; then
    echo "User '$USERNAME' already exists — nothing to do." >&2
    exit 0
fi

echo "== Creating $USERNAME =="
echo "Groups: $GROUPS"
read -r -p "Proceed? [y/N] " confirm
[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Aborted."; exit 1; }

# Drop groups that don't exist on this system (e.g. 'seat' without
# seatd/elogind) rather than failing the whole command.
existing_groups=""
IFS=',' read -ra requested <<< "$GROUPS"
for g in "${requested[@]}"; do
    if getent group "$g" >/dev/null 2>&1; then
        existing_groups="${existing_groups:+$existing_groups,}$g"
    else
        echo "  (skipping missing group: $g)"
    fi
done

useradd -m -G "$existing_groups" -s /bin/bash -c "modern_dotfile dev account" "$USERNAME"
passwd "$USERNAME"

echo
echo "Created $USERNAME with groups: $existing_groups"
echo "Next steps (as $USERNAME):"
echo "  git clone <this-repo-url> ~/modern_dotfile"
echo "  cd ~/modern_dotfile && ./install/install.sh --profile m0"
echo
echo "Verify isolation from your own account afterwards:"
echo "  scripts/check-isolation.sh"
