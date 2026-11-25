#!/usr/bin/env bash
# Create a read-only GitHub deploy key.
# Prints the public half. Add it under GitHub → Settings → Deploy keys
# and leave "Allow write access" off. The private half stays in
# secrets/github-deploy-key (gitignored). iso-build.sh embeds it; an
# installed system reads ~/.config/modern/deploy_key.
# No passphrase: Settings → Update has no terminal to ask for one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="$ROOT/secrets/github-deploy-key"

if [ -e "$KEY" ] || [ -L "$KEY" ]; then
    printf 'deploy-key-init: %s already exists (left untouched)\n' "$KEY" >&2
else
    command -v ssh-keygen >/dev/null 2>&1 || {
        printf 'deploy-key-init: ssh-keygen is required\n' >&2
        exit 1
    }
    mkdir -p "$ROOT/secrets"
    ssh-keygen -t ed25519 -N "" -C "modernos-deploy-readonly" -f "$KEY" >/dev/null
    chmod 0600 "$KEY"
    chmod 0700 "$ROOT/secrets"
fi

[ -f "$KEY.pub" ] || {
    printf 'deploy-key-init: missing %s\n' "$KEY.pub" >&2
    exit 1
}
printf 'Add this public key: GitHub → this repo → Settings → Deploy keys → Add deploy key.\nLeave "Allow write access" off.\n\n'
cat "$KEY.pub"
