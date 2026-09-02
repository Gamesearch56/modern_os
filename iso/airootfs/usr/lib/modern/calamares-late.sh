#!/usr/bin/env bash
# Calamares late: clone the ISO pin, install.sh --profile m0 --yes, provision.
# Runs as root inside the target. Refuses when MODERN_PROTECT_HOME is
# set and exists.
set -euo pipefail

ALLOWED_URL="https://github.com/Gamesearch56/modern_dotfile.git"
TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'

die() { printf 'calamares-late: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'calamares-late: %s\n' "$*"; }

if [ -n "${MODERN_PROTECT_HOME:-}" ] && [ -d "${MODERN_PROTECT_HOME%/}" ]; then
    die "refusing to run while MODERN_PROTECT_HOME is set and exists"
fi
if [ "$(id -u)" -ne 0 ]; then
    die "must run as root in the install target"
fi

USERNAME=""
if [ -n "${MODERN_CALAMARES_USER:-}" ]; then
    USERNAME="$MODERN_CALAMARES_USER"
else
    USERNAME="$(awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }' /etc/passwd || true)"
fi
[ -n "$USERNAME" ] || die "no human user in the target"
id "$USERNAME" >/dev/null 2>&1 || die "user $USERNAME does not exist"
USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
[ -n "$USER_HOME" ] || die "no home for $USERNAME"

PIN_FILE="/usr/lib/modern/iso-pin"
PIN="${MODERN_ISO_TAG:-}"
if [ -z "$PIN" ] && [ -f "$PIN_FILE" ]; then
    PIN="$(tr -d '[:space:]' <"$PIN_FILE")"
fi
[[ "$PIN" =~ $TAG_RE ]] || die "ISO pin is not a release tag (got '${PIN:-empty}')"

if [ ! -e /etc/resolv.conf ] || [ ! -s /etc/resolv.conf ]; then
    if [ -e /run/systemd/resolve/stub-resolv.conf ]; then
        cp /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
fi

install -d -m 0750 "$USER_HOME"
REPO="$USER_HOME/modern_dotfile"
rm -rf "$REPO"
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    /usr/bin/git -c core.hooksPath=/dev/null -c protocol.file.allow=never \
    -c fetch.recurseSubmodules=false \
    clone --depth 1 --branch "$PIN" "$ALLOWED_URL" "$REPO"
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    /usr/bin/git -C "$REPO" -c core.hooksPath=/dev/null config core.hooksPath /dev/null
chown -R "$USERNAME:$USERNAME" "$REPO" "$USER_HOME"

install -d -m 0750 /etc/sudoers.d
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$USERNAME" >/etc/sudoers.d/99-modern-calamares
chmod 0440 /etc/sudoers.d/99-modern-calamares

sudo -iu "$USERNAME" env HOME="$USER_HOME" \
    XDG_CONFIG_HOME="$USER_HOME/.config" \
    XDG_STATE_HOME="$USER_HOME/.local/state" \
    XDG_DATA_HOME="$USER_HOME/.local/share" \
    bash "$REPO/install/install.sh" --profile m0 --yes \
    || die "install.sh --profile m0 --yes failed"

export MODERN_ISO_PROVISION=1
bash "$REPO/install/system/provision-iso.sh" "$USERNAME" \
    || die "provision-iso.sh failed"

log "late install finished for $USERNAME at $PIN"
