#!/usr/bin/env bash
# Privileged system update for Settings → Update. One pkexec from
# `modern update` so snapper, pacman and the desktop release's root
# steps (--root-plan, written by install.sh) share a single auth prompt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT=0
PLAN=""
usage() {
    printf 'usage: update-apply.sh [--snapshot|--no-snapshot] [--root-plan FILE]\n' >&2
}
while [ $# -gt 0 ]; do
    case "$1" in
        --snapshot)
            SNAPSHOT=1
            ;;
        --no-snapshot)
            SNAPSHOT=0
            ;;
        --root-plan)
            [ $# -ge 2 ] || { usage; exit 2; }
            PLAN="$2"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
    shift
done

if [ "$(id -u)" -ne 0 ]; then
    printf 'update-apply: must run as root (pkexec)\n' >&2
    exit 1
fi

if [ "$SNAPSHOT" -eq 1 ]; then
    if command -v snapper >/dev/null 2>&1 \
        && snapper list-configs >/dev/null 2>&1 \
        && snapper list-configs 2>/dev/null | grep -q root; then
        snapper -c root create --description "ModernOS Update"
        uid="${PKEXEC_UID:-${SUDO_UID:-}}"
        home=""
        if [ -n "$uid" ]; then
            home="$(getent passwd "$uid" | cut -d: -f6 || true)"
        fi
        cfg=""
        if [ -n "$home" ]; then
            cfg="$home/.config/modern/config.json"
        fi
        "$SCRIPT_DIR/snapper-gc.sh" prune-from-config "$cfg" || true
    fi
fi

PACMAN="${MODERN_PACMAN:-/usr/bin/pacman}"
"$PACMAN" -Syu --noconfirm

[ -n "$PLAN" ] && [ -s "$PLAN" ] || exit 0

# shellcheck source=lib/pkg-name.sh
source "$SCRIPT_DIR/lib/pkg-name.sh"
# shellcheck source=lib/root-plan.sh
source "$SCRIPT_DIR/lib/root-plan.sh"
assert_root_plan_file "$PLAN" || exit 1
read_root_plan "$PLAN"

if [ ${#ROOT_PLAN_PKGS[@]} -gt 0 ]; then
    # Same provider swap as install/lib/pkg.sh install_native.
    "$PACMAN" -Rdd --noconfirm jack2 jack2-dbus lib32-jack2 \
        pulseaudio pulseaudio-bluetooth pulseaudio-jack \
        pipewire-media-session >/dev/null 2>&1 || true
    "$PACMAN" -S --needed --noconfirm "${ROOT_PLAN_PKGS[@]}"
fi

if [ "$ROOT_PLAN_GREETD" -eq 1 ]; then
    user="$(getent passwd "${PKEXEC_UID:-${SUDO_UID:-}}" | cut -d: -f1 || true)"
    if [ -z "$user" ] || [ "$user" = root ]; then
        printf 'update-apply: greetd needs the calling user (PKEXEC_UID/SUDO_UID)\n' >&2
        exit 1
    fi
    # greetd.sh logs through install/lib/log.sh; a root-owned install.log
    # in the user's checkout would break the next unprivileged install.
    LOG_FILE=/dev/null
    DRY_RUN=0
    export LOG_FILE DRY_RUN REPO_ROOT
    # shellcheck source=../install/lib/log.sh
    source "$REPO_ROOT/install/lib/log.sh"
    # shellcheck source=../install/lib/ui.sh
    source "$REPO_ROOT/install/lib/ui.sh"
    # shellcheck source=../install/lib/greetd.sh
    source "$REPO_ROOT/install/lib/greetd.sh"
    greetd_apply "$user"
fi
