#!/usr/bin/env bash
# Verifies that developing modern_dotfile has not affected the current
# daily-driver account (bastianweigand) or applied any gated system-wide
# change. See docs/ISOLATION.md for the full policy this enforces.
#
# Usage: scripts/check-isolation.sh [--init] [--allow-gated]
#   --init         Record the baseline to compare future runs against.
#   --allow-gated  Skip the gated-system-state checks (use once you've
#                  deliberately opened the gate and applied install/system/).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/modern-dotfile"
BASELINE="$STATE_DIR/isolation-baseline.txt"
CURRENT_USER_HOME="/home/bastianweigand"
ALLOW_GATED=0
INIT=0

for arg in "$@"; do
    case "$arg" in
        --init) INIT=1 ;;
        --allow-gated) ALLOW_GATED=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

mkdir -p "$STATE_DIR"

fail=0
note() { printf '  - %s\n' "$1"; }
bad() { printf '\033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
ok() { printf '\033[32mOK\033[0m   %s\n' "$1"; }

hash_hook() {
    [ -f /etc/pacman.d/hooks/package_list.hook ] && sha256sum /etc/pacman.d/hooks/package_list.hook | cut -d' ' -f1 || echo "absent"
}

if [ "$INIT" -eq 1 ]; then
    {
        echo "hook_hash=$(hash_hook)"
        echo "baseline_time=$(date +%s)"
        { find "$CURRENT_USER_HOME" -maxdepth 3 -not -path "$REPO_ROOT*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 || true; }
    } > "$BASELINE"
    echo "Baseline recorded at $BASELINE"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    echo "No baseline found. Run with --init first." >&2
    exit 2
fi

# 1. pacman hook unchanged
current_hook_hash="$(hash_hook)"
baseline_hook_hash="$(grep '^hook_hash=' "$BASELINE" | cut -d= -f2)"
if [ "$current_hook_hash" = "$baseline_hook_hash" ]; then
    ok "package_list.hook unchanged"
else
    bad "package_list.hook changed since baseline"
    note "This should never happen — the hook is deliberately left alone."
fi

# 2. no symlink in bastianweigand's ~/.config points into this repo or devuser
if [ -d "$CURRENT_USER_HOME/.config" ]; then
    bad_links=$(find "$CURRENT_USER_HOME/.config" -maxdepth 6 -type l 2>/dev/null | while read -r link; do
        target="$(readlink -f "$link" 2>/dev/null || true)"
        case "$target" in
            "$REPO_ROOT"*|/home/devuser*) echo "$link -> $target" ;;
        esac
    done)
    if [ -z "$bad_links" ]; then
        ok "no symlink in ~/.config points into modern_dotfile or devuser"
    else
        bad "found symlinks pointing into modern_dotfile/devuser:"
        while IFS= read -r line; do
            printf '    %s\n' "$line"
        done <<< "$bad_links"
    fi
else
    ok "no ~/.config to check"
fi

# 3. gated system state untouched, unless explicitly allowed.
# Creating the devuser *account* is the supported test path and is NOT
# a leak — greetd/polkit/sysctl/tmpfiles/ESP-hook are the dangerous ones.
# Plymouth in mkinitcpio is not checked: this machine may already use it.
if [ "$ALLOW_GATED" -eq 0 ]; then
    gated_hits=""
    systemctl is-enabled greetd.service >/dev/null 2>&1 && gated_hits="${gated_hits}greetd.service enabled"$'\n'
    [ -e /etc/polkit-1/actions/link.modern.usermanager.policy ] && gated_hits="${gated_hits}modern-usersd polkit action installed"$'\n'
    [ -e /usr/local/bin/modern-usersd ] && gated_hits="${gated_hits}modern-usersd binary installed"$'\n'
    [ -e /etc/tmpfiles.d/modern-session.conf ] && gated_hits="${gated_hits}/etc/tmpfiles.d/modern-session.conf present"$'\n'
    [ -e /etc/sysctl.d/99-modern-gaming.conf ] && gated_hits="${gated_hits}/etc/sysctl.d/99-modern-gaming.conf present"$'\n'
    [ -e /etc/pacman.d/hooks/esp-backup.hook ] && gated_hits="${gated_hits}/etc/pacman.d/hooks/esp-backup.hook present"$'\n'

    if [ -z "$gated_hits" ]; then
        ok "no gated system-wide change has been applied"
    else
        bad "gated system-wide changes detected (pass --allow-gated if deliberate):"
        while IFS= read -r line; do
            [ -n "$line" ] && printf '    %s\n' "$line"
        done <<< "$gated_hits"
    fi
else
    echo "  (gated-state checks skipped: --allow-gated)"
fi

if id devuser >/dev/null 2>&1; then
    ok "devuser account exists (expected for testing; not a leak)"
else
    ok "devuser account not created yet (optional: sudo install/system/create-devuser.sh)"
fi

# 4. home mtime is advisory — the daily-driver account keeps running
# (Steam, Cursor, caches) so -newer baseline will almost always fire.
# Real isolation is checks 1–3 (hook, no repo symlinks, gated units).
outside_writes=$(find "$CURRENT_USER_HOME" -maxdepth 2 -newer "$BASELINE" -not -path "$REPO_ROOT*" 2>/dev/null | grep -v "^$CURRENT_USER_HOME\$" || true)
if [ -z "$outside_writes" ]; then
    ok "no new/modified top-level files under bastianweigand's home since baseline"
else
    printf '\033[33mWARN\033[0m home has changed since baseline (expected on a live account); not a leak unless a symlink/gated check failed\n'
fi

if [ "$fail" -eq 0 ]; then
    echo
    echo "Isolation check passed."
else
    echo
    echo "Isolation check FAILED — see above." >&2
    exit 1
fi
