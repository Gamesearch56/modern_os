#!/usr/bin/env bash
# Pre-install sanity checks. Source, never execute directly.
# TARGET is exported by install.sh before this file is sourced.
: "${TARGET:=}"

preflight_checks() {
    local failures=0

    log_phase "Preflight checks"

    if [ "$EUID" -eq 0 ]; then
        log_error "Do not run install.sh as root. It escalates with sudo/pkexec only when needed."
        failures=$((failures + 1))
    else
        log_ok "not running as root"
    fi

    # Optional live-home guard: set MODERN_PROTECT_HOME to a directory
    # this installer must never stow into. Unset means the guard is idle.
    # --allow-live-home overrides it. See docs/ISOLATION.md.
    local protected="${MODERN_PROTECT_HOME:-}"
    local target="${TARGET%/}"
    protected="${protected%/}"
    if [ "${ALLOW_LIVE_HOME:-0}" -eq 1 ]; then
        log_warn "live-home guard disabled (--allow-live-home); stow target is $target"
    elif [ -n "$protected" ] && [ -d "$protected" ]; then
        case "$target" in
            "$protected"|"$protected"/*)
                log_error "Refusing to stow into protected home ($protected)."
                log_error "  Use --target with another home, or pass --allow-live-home."
                failures=$((failures + 1))
                ;;
            *)
                log_ok "stow target is not the protected home ($target)"
                ;;
        esac
    else
        log_ok "live-home guard idle (MODERN_PROTECT_HOME unset or missing)"
    fi

    if ! command -v pacman >/dev/null 2>&1; then
        log_error "pacman not found — this installer targets Arch Linux only."
        failures=$((failures + 1))
    else
        log_ok "pacman present"
    fi

    for bin in git jq stow; do
        if command -v "$bin" >/dev/null 2>&1; then
            log_ok "$bin present"
        else
            log_warn "$bin not yet installed — will be installed by the base layer"
        fi
    done

    # btrfs + active swapfile check (docs/BACKUP.md: btrfs refuses to
    # snapshot a subvolume containing an active swapfile).
    if command -v findmnt >/dev/null 2>&1 && findmnt -n -o FSTYPE / | grep -q btrfs; then
        log_ok "root is btrfs"
        if swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/'; then
            local swap_path
            swap_path="$(swapon --show=NAME --noheadings | head -1)"
            local swap_subvol
            swap_subvol="$(findmnt -n -o TARGET --target "$swap_path" 2>/dev/null || echo /)"
            if [ "$swap_subvol" = "/" ] || [ "$swap_subvol" = "" ]; then
                log_warn "Active swapfile ($swap_path) appears to live directly inside '@' or '/'."
                log_warn "  btrfs refuses to snapshot a subvolume containing an active swapfile."
                log_warn "  See docs/BACKUP.md before enabling snapper — this blocks 'backup' phase, not M0."
            else
                log_ok "swapfile lives in its own subvolume/mount ($swap_subvol)"
            fi
        fi
    fi

    # Disk space floor — see docs/BACKUP.md, the audited root was 82% full.
    local avail_pct
    avail_pct="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
    if [ -n "$avail_pct" ] && [ "$avail_pct" -ge 90 ]; then
        log_warn "Root filesystem is ${avail_pct}% full. Package installs and snapshots need headroom."
    else
        log_ok "root filesystem has headroom (${avail_pct:-unknown}% used)"
    fi

    if [ "$failures" -gt 0 ]; then
        die "$failures preflight check(s) failed. Fix them before continuing."
    fi

    log_ok "Preflight checks passed"
}
