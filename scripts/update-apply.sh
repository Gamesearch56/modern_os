#!/usr/bin/env bash
# Privileged system update for Settings → Update. One pkexec from
# `modern update` so snapper, pacman and the desktop release's root
# steps (--root-plan, written by install.sh) share a single auth prompt.
# The work itself runs in the modern-system-update service (see
# lib/update-guard.sh); this process only streams its log.
#
# Exit status (Settings names each one, see lib/modern-update.sh):
#   3  packages failed halfway and the pre-update snapshot was restored
#   5  the pre-update snapshot could not be created; nothing changed
#   7  packages failed before anything was changed
#   8  packages failed halfway and stay half-applied; the next update
#      finishes them
#   10 another package manager holds the pacman database
#   11 a step this ModernOS version needs after the packages failed
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
STATUS_FIFO=""
ARGS=("$@")
usage() {
    printf 'usage: update-apply.sh [--snapshot|--no-snapshot] [--root-plan FILE] [--progress] [--wait] [--status-fifo FILE] [--boot-repair]\n' >&2
}
# Stage markers for Services/UpdateProgress.qml. pacman's own messages
# are translated, so the stages cannot be read from them.
progress() {
    [ "$PROGRESS" -eq 0 ] || printf '@@progress %s\n' "$1"
}
# A step aborted by set -e still says which step it was, and exits with
# STEP_RC so Settings can name it.
STEP=""
STEP_RC=1
FAILED=0
fail() {
    local rc="$1"
    shift
    FAILED=1
    printf 'update-apply: %s\n' "$*" >&2
    exit "$rc"
}
on_exit() {
    local rc=$?
    [ "$rc" -ne 0 ] && [ "$FAILED" -eq 0 ] && [ -n "$STEP" ] || return 0
    printf 'update-apply: %s failed (exit %s)\n' "$STEP" "$rc" >&2
    exit "$STEP_RC"
}
trap on_exit EXIT
# Sets SNAP_ID. Exit 5 when snapper cannot take the snapshot, before
# anything else has run.
take_snapshot() {
    progress snapshot
    if ! snapper list-configs 2>/dev/null | grep -q root; then
        fail 5 "snapper is installed but has no root config; set it up in Settings → Backup or turn off the pre-update snapshot"
    fi
    update_guard_esp_backup || printf 'update-apply: WARN could not copy /boot into the snapshot\n' >&2
    snapper -c root create --description "ModernOS Update" \
        || fail 5 "could not create the pre-update snapshot; nothing was changed"
    SNAP_ID="$(update_guard_last_snapshot)"
    [ -n "$SNAP_ID" ] || fail 5 "snapper did not list the new pre-update snapshot; nothing was changed"
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
        --status-fifo)
            [ $# -ge 2 ] || { usage; exit 2; }
            STATUS_FIFO="$2"
            shift
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

# Password is already accepted: pkexec does not start this script until
# then. Take the snapshot before telling the caller it may log progress
# or run the rest of the update. A failed snapshot stops here.
if [ "$WAIT" -eq 1 ] && [ -z "${MODERN_UPDATE_UNIT:-}" ]; then
    # shellcheck source=lib/update-guard.sh
    source "$SCRIPT_DIR/lib/update-guard.sh"
    # shellcheck source=../install/lib/kernel-boot.sh
    source "$REPO_ROOT/install/lib/kernel-boot.sh"
    if [ ! -s "$UPDATE_MARK" ] && [ "$SNAPSHOT" -eq 1 ] && [ "$BOOT_REPAIR" -eq 0 ] \
        && command -v snapper >/dev/null 2>&1; then
        kernel_boot_prepare
        take_snapshot
        MODERN_SNAPSHOT_ID="$SNAP_ID"
        export MODERN_SNAPSHOT_ID
    fi
    if [ -n "$STATUS_FIFO" ]; then
        printf 'ready\n' >"$STATUS_FIFO"
    fi
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
update_guard_pacman_lock \
    || fail 10 "another program is installing packages; let it finish, then update again"

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
STEP="preparing the boot files"
kernel_boot_prepare
STEP=""

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
    STEP="repairing the boot menu"
    kernel_boot_reconcile
    STEP=""
fi
# A plan written while this process waited means packages or greetd
# still have to run. Do not stop after the boot heal in that case.
if [ "$BOOT_REPAIR" -eq 1 ] && [ "$REPAIR" -eq 0 ] \
    && { [ -z "$PLAN" ] || [ ! -s "$PLAN" ]; }; then
    rm -f "$UPDATE_MARK"
    progress finish
    exit 0
fi

# The --wait process already took the snapshot before it said ready.
# This path is the system service, and a direct run that did not wait.
snap="${MODERN_SNAPSHOT_ID:-}"
if [ -z "$snap" ] && [ "$SNAPSHOT" -eq 1 ] && [ "$REPAIR" -eq 0 ] && [ "$BOOT_REPAIR" -eq 0 ] \
    && command -v snapper >/dev/null 2>&1; then
    take_snapshot
    snap="$SNAP_ID"
fi
if [ -n "$snap" ]; then
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
            fail 3 "restored the system from before the update; restart to finish"
        fi
        printf 'update-apply: could not restore snapshot %s; restore it from Settings → Backup, or update again to finish the packages\n' "$snap" >&2
    fi
fi
# The package upgrade removes the previous modules even when the boot
# menu still points at that kernel. Reconcile whether or not the sync
# finished, so a reboot loads the kernel that is actually installed.
STEP="pointing the boot menu at the installed kernel"
kernel_boot_reconcile
STEP=""
if [ "$pacman_ok" -ne 1 ]; then
    # The mark stays only when packages changed, so the next run repairs.
    if update_guard_partial "$mark"; then
        fail 8 "packages stopped halfway; update again to finish them before restarting"
    fi
    rm -f "$UPDATE_MARK"
    fail 7 "the package update failed before anything was changed"
fi
rm -f "$UPDATE_MARK"

if [ -z "$PLAN" ] || [ ! -s "$PLAN" ]; then
    progress finish
    exit 0
fi

# shellcheck source=lib/pkg-name.sh
source "$SCRIPT_DIR/lib/pkg-name.sh"
# shellcheck source=lib/root-plan.sh
source "$SCRIPT_DIR/lib/root-plan.sh"
assert_root_plan_file "$PLAN" || fail 11 "refusing the root plan $PLAN"
read_root_plan "$PLAN"

if [ ${#ROOT_PLAN_PKGS[@]} -gt 0 ]; then
    # Same provider swap as install/lib/pkg.sh install_native.
    "$PACMAN" -Rdd --noconfirm jack2 jack2-dbus lib32-jack2 \
        pulseaudio pulseaudio-bluetooth pulseaudio-jack \
        pipewire-media-session >/dev/null 2>&1 || true
    "$PACMAN" -S --needed --noconfirm "${ROOT_PLAN_PKGS[@]}" \
        || fail 11 "could not install the packages this ModernOS version needs: ${ROOT_PLAN_PKGS[*]}"
fi

if [ "$ROOT_PLAN_GREETD" -eq 1 ]; then
    user="$(getent passwd "${PKEXEC_UID:-${SUDO_UID:-}}" | cut -d: -f1 || true)"
    if [ -z "$user" ] || [ "$user" = root ]; then
        fail 11 "greetd needs the calling user (PKEXEC_UID/SUDO_UID)"
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
    STEP="setting up the login screen" STEP_RC=11
    greetd_apply "$user"
fi

if [ "${ROOT_PLAN_SPLASH:-0}" -eq 1 ]; then
    # shellcheck source=../install/system/plymouth/apply.sh
    source "$REPO_ROOT/install/system/plymouth/apply.sh"
    STEP="setting up the boot splash" STEP_RC=11
    plymouth_apply /
    if [ "$plymouth_rebuild" -eq 1 ]; then
        STEP="rebuilding the boot image for the splash"
        mkinitcpio -P
    fi
fi

if [ "${ROOT_PLAN_PORTAL:-0}" -eq 1 ]; then
    if portal_pkg="$(root_plan_portal_pkg)"; then
        "$PACMAN" -U --needed --noconfirm "$portal_pkg" \
            || printf 'update-apply: WARN the file chooser portal was not installed\n' >&2
    else
        printf 'update-apply: WARN refusing the file chooser portal package\n' >&2
    fi
fi

if [ "${ROOT_PLAN_MIRRORS:-0}" -eq 1 ]; then
    # shellcheck source=../install/lib/mirrors.sh
    source "$REPO_ROOT/install/lib/mirrors.sh"
    mirrors_apply || printf 'update-apply: WARN mirror refresh was not enabled\n' >&2
fi
STEP=""
progress finish
