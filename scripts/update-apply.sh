#!/usr/bin/env bash
# Privileged system update for Settings → Update. One pkexec from
# `modern update` so snapper, pacman and the desktop release's root
# steps (--root-plan, written by install.sh) share a single auth prompt.
# The work itself runs in the modern-system-update service (see
# lib/update-guard.sh); this process only streams its log. Exit 3: a
# half-applied update was rolled back to the pre-update snapshot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT=0
PLAN=""
ARGS=("$@")
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

# shellcheck source=lib/update-guard.sh
source "$SCRIPT_DIR/lib/update-guard.sh"
rc=0
update_guard_detach "$0" "${ARGS[@]}" || rc=$?
[ "$rc" -eq 255 ] || exit "$rc"

PACMAN="${MODERN_PACMAN:-/usr/bin/pacman}"
if [ -s "$UPDATE_MARK" ]; then
    printf 'update-apply: the previous update was interrupted; finishing it\n'
    REPAIR=1
else
    REPAIR=0
fi

snap=""
if [ "$SNAPSHOT" -eq 1 ] && [ "$REPAIR" -eq 0 ]; then
    if command -v snapper >/dev/null 2>&1 \
        && snapper list-configs >/dev/null 2>&1 \
        && snapper list-configs 2>/dev/null | grep -q root; then
        update_guard_esp_backup || printf 'update-apply: WARN could not copy /boot into the snapshot\n' >&2
        snapper -c root create --description "ModernOS Update"
        snap="$(update_guard_last_snapshot)"
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

mkdir -p "$(dirname "$UPDATE_MARK")"
[ "$REPAIR" -eq 1 ] || printf '%s\n' "${snap:-none}" >"$UPDATE_MARK"
mark="$(update_guard_log_mark)"
if ! "$PACMAN" -Syu --noconfirm; then
    if update_guard_partial "$mark" && [ -n "$snap" ]; then
        printf 'update-apply: packages failed halfway; restoring snapshot %s\n' "$snap" >&2
        if "$SCRIPT_DIR/snapper-restore.sh" "$snap"; then
            rm -f "$UPDATE_MARK"
            printf 'update-apply: restored the system from before the update; restart to finish\n' >&2
            exit 3
        fi
    fi
    # The mark stays only when packages changed, so the next run repairs.
    update_guard_partial "$mark" || rm -f "$UPDATE_MARK"
    exit 1
fi
if [ "$REPAIR" -eq 1 ]; then
    # Hooks of the cut-off run may never have put the kernel on the ESP.
    mapfile -t kernels < <("$PACMAN" -Qqo /usr/lib/modules/*/vmlinuz 2>/dev/null | sort -u)
    [ ${#kernels[@]} -eq 0 ] || "$PACMAN" -S --noconfirm "${kernels[@]}"
fi
rm -f "$UPDATE_MARK"

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
