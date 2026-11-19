#!/usr/bin/env bash
# Privileged system update for Settings → Update. One pkexec from
# `modern update` so snapper, pacman and the desktop release's root
# steps (--root-plan, written by install.sh) share a single auth prompt.
# The work itself runs in the modern-system-update service (see
# lib/update-guard.sh); this process only streams its log. Exit 3: a
# half-applied update was rolled back to the pre-update snapshot.
#
# --wait: `modern update` starts this (and with it the password prompt)
# before the desktop release, which writes the root plan. One line on
# stdin then says "go"; anything else, or EOF, means no root work.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT=0
PLAN=""
PROGRESS=0
WAIT=0
BOOT_REPAIR=0
ARGS=("$@")
usage() {
    printf 'usage: update-apply.sh [--snapshot|--no-snapshot] [--root-plan FILE] [--progress] [--wait] [--boot-repair]\n' >&2
}
# Stage markers for Services/UpdateProgress.qml. pacman's own messages
# are translated, so the stages cannot be read from them.
progress() {
    [ "$PROGRESS" -eq 0 ] || printf '@@progress %s\n' "$1"
}
while [ $# -gt 0 ]; do
    case "$1" in
        --snapshot)
            SNAPSHOT=1
            ;;
        --progress)
            PROGRESS=1
            ;;
        --wait)
            WAIT=1
            ;;
        --boot-repair)
            BOOT_REPAIR=1
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

if [ "$WAIT" -eq 1 ] && [ -z "${MODERN_UPDATE_UNIT:-}" ]; then
    go=""
    read -r go || true
    [ "$go" = go ] || exit 0
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
# shellcheck source=lib/pacman-conf.sh
source "$SCRIPT_DIR/lib/pacman-conf.sh"
pacman_conf_repair "${MODERN_PACMAN_CONF:-/etc/pacman.conf}" \
    || printf 'update-apply: WARN could not tidy pacman.conf\n' >&2

# Pin ALL_kver and the boot hooks before pacman. The kernel hook in this
# same transaction is what copies the new vmlinuz and rebuilds the
# initramfs; a preset without that path skips both. Shelter the kernel
# that is running now first: the remove hook deletes the preset's images
# before the new ones exist.
# shellcheck source=../install/lib/kernel-boot.sh
source "$REPO_ROOT/install/lib/kernel-boot.sh"
kernel_boot_prepare

# A cut-off upgrade can leave the new modules installed and the menu on
# the previous kernel. Reinstall that kernel from the local cache before
# asking the network, then point the menu at it. --boot-repair is the
# same heal with no package sync, so it works with no network.
if [ "$REPAIR" -eq 1 ]; then
    mapfile -t kernels < <("$PACMAN" -Qqo /usr/lib/modules/*/vmlinuz 2>/dev/null | sort -u)
    if [ ${#kernels[@]} -gt 0 ]; then
        # Cache miss must not skip the menu heal below.
        "$PACMAN" -S --noconfirm "${kernels[@]}" || true
    fi
fi
if [ "$BOOT_REPAIR" -eq 1 ] || [ "$REPAIR" -eq 1 ] || kernel_boot_needs_repair; then
    kernel_boot_reconcile
fi
# A plan written while this process waited means packages or greetd
# still have to run. Do not stop after the boot heal in that case.
if [ "$BOOT_REPAIR" -eq 1 ] && [ "$REPAIR" -eq 0 ] \
    && { [ -z "$PLAN" ] || [ ! -s "$PLAN" ]; }; then
    rm -f "$UPDATE_MARK"
    progress finish
    exit 0
fi

# Snapshot after the heal. A restore must bring back a kernel that
# matches the modules, including the recovery copy just taken.
progress snapshot
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
progress pacman
pacman_ok=0
if "$PACMAN" -Syu --noconfirm; then
    pacman_ok=1
else
    if update_guard_partial "$mark" && [ -n "$snap" ]; then
        printf 'update-apply: packages failed halfway; restoring snapshot %s\n' "$snap" >&2
        if "$SCRIPT_DIR/snapper-restore.sh" "$snap"; then
            rm -f "$UPDATE_MARK"
            printf 'update-apply: restored the system from before the update; restart to finish\n' >&2
            exit 3
        fi
    fi
fi
# The package upgrade removes the previous modules even when the boot
# menu still points at that kernel. Reconcile whether or not the sync
# finished, so a reboot loads the kernel that is actually installed.
kernel_boot_reconcile
if [ "$pacman_ok" -ne 1 ]; then
    # The mark stays only when packages changed, so the next run repairs.
    update_guard_partial "$mark" || rm -f "$UPDATE_MARK"
    exit 1
fi
rm -f "$UPDATE_MARK"
progress finish

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

if [ "${ROOT_PLAN_SPLASH:-0}" -eq 1 ]; then
    # shellcheck source=../install/system/plymouth/apply.sh
    source "$REPO_ROOT/install/system/plymouth/apply.sh"
    plymouth_apply /
    if [ "$plymouth_rebuild" -eq 1 ]; then
        mkinitcpio -P
    fi
fi
