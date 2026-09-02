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
account_groups="wheel,video,input,audio,render,seat,i2c"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 [username]" >&2
    exit 1
fi

if id "$USERNAME" >/dev/null 2>&1; then
    echo "User '$USERNAME' already exists — nothing to do." >&2
    exit 0
fi

echo "== Creating $USERNAME =="
echo "Groups: $account_groups"
read -r -p "Proceed? [y/N] " confirm
[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Aborted."; exit 1; }

# Drop groups that don't exist on this system (e.g. 'seat' without
# seatd/elogind) rather than failing the whole command.
existing_groups=""
IFS=',' read -ra requested <<< "$account_groups"
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
echo
echo "This does not change autologin or greetd. Log in as $USERNAME on"
echo "another TTY to start a session."
echo
echo "Next steps (as $USERNAME — clone a copy if the other home is 700):"
echo "  sudo -iu $USERNAME"
echo "  git clone <this-repo-url> ~/modern_dotfile"
echo "  cd ~/modern_dotfile && ./install/install.sh --profile m0 --dry-run"
echo "  ./install/install.sh --profile m0"
echo
echo "Start a test session without leaving another desktop:"
echo "  Ctrl+Alt+F3  →  login as $USERNAME  →  start-hyprland"
echo "Return: Ctrl+Alt+F1 or F2 (whichever still shows your other session)."
echo
echo "Rollback this account: sudo userdel -r $USERNAME"
echo "Verify gated files were not applied:"
echo "  scripts/check-isolation.sh"
