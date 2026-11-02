#!/usr/bin/env bash
# pam_exec (expose_authtok, seteuid) on greetd auth. stdin is the password
# just typed. A login keyring that does not open with that password makes
# gnome-keyring ask to create "Default Keyring"; an empty one then makes
# Vivaldi refuse its secret store. Drop the stale file so pam_gnome_keyring
# creates a new login keyring with this password, and make it the default.
set -euo pipefail
umask 077

password=""
IFS= read -r password || true

home="${MODERN_KEYRING_HOME:-}"
if [ -z "$home" ]; then
    user="${PAM_USER:-}"
    [ -n "$user" ] || exit 0
    home="$(getent passwd -- "$user" 2>/dev/null | cut -d: -f6 || true)"
fi
[ -n "$home" ] || exit 0

dir="$home/.local/share/keyrings"
mkdir -p "$dir"
chmod 0700 "$dir" || true

login="$dir/login.keyring"
checker="$(cd "$(dirname "$0")" && pwd)/keyring-match.py"
if [ -f "$login" ] && [ -f "$checker" ]; then
    status=0
    printf '%s' "$password" | /usr/bin/python3 "$checker" "$login" || status=$?
    if [ "$status" -eq 1 ]; then
        rm -f -- "$login"
    fi
fi

printf 'login\n' >"$dir/default"
chmod 0600 "$dir/default" || true
password=""
exit 0
