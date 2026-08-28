#!/usr/bin/env bash
# Change the current user's password via pkexec chpasswd.
# Password is read from stdin (one line) — never argv, never logged.
set -euo pipefail

user="${1:-}"
if [ -z "$user" ] || [ "$user" != "${USER:-}" ]; then
    echo "passwd-set: refusing user mismatch" >&2
    exit 2
fi

IFS= read -r pass || true
if [ -z "${pass:-}" ]; then
    echo "passwd-set: empty password" >&2
    exit 2
fi

printf '%s:%s\n' "$user" "$pass" | pkexec chpasswd
unset pass
