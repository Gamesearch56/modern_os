#!/usr/bin/env bash
# Verifies that developing this repo has not applied gated system-wide
# files. If MODERN_PROTECT_HOME is set, also checks that home for
# unexpected stow into this clone. See docs/ISOLATION.md.
#
# Usage: scripts/check-isolation.sh [--init] [--allow-gated]
#   --init         Record the baseline to compare future runs against.
#   --allow-gated  Skip the gated-system-state checks (use once you've
#                  deliberately opened the gate and applied install/system/).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/modern-dotfile"
BASELINE="$STATE_DIR/isolation-baseline.txt"
PROTECTED="${MODERN_PROTECT_HOME:-}"
PROTECTED="${PROTECTED%/}"
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
bad() { printf '\033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
ok() { printf '\033[32mOK\033[0m   %s\n' "$1"; }

if [ "$INIT" -eq 1 ]; then
    {
        echo "baseline_time=$(date +%s)"
        echo "protected=${PROTECTED}"
        if [ -n "$PROTECTED" ] && [ -d "$PROTECTED" ]; then
            find "$PROTECTED" -maxdepth 3 -not -path "$REPO_ROOT*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 || true
        fi
    } >"$BASELINE"
    echo "Baseline recorded at $BASELINE"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    echo "No baseline found. Run with --init first." >&2
    exit 2
fi

# 1. no symlink in a protected ~/.config points into this repo
if [ -n "$PROTECTED" ] && [ -d "$PROTECTED/.config" ]; then
    bad_links=$(find "$PROTECTED/.config" -maxdepth 6 -type l 2>/dev/null | while read -r link; do
        target="$(readlink -f "$link" 2>/dev/null || true)"
        case "$target" in
            "$REPO_ROOT"*) echo "$link -> $target" ;;
        esac
    done)
    if [ -z "$bad_links" ]; then
        ok "no symlink in protected ~/.config points into this clone"
    else
        bad "found symlinks pointing into this clone:"
        while IFS= read -r line; do
            printf '    %s\n' "$line"
        done <<<"$bad_links"
    fi
elif [ -n "$PROTECTED" ]; then
    ok "no protected ~/.config to check"
else
    ok "live-home guard idle (MODERN_PROTECT_HOME unset)"
fi

# 2. gated system state untouched, unless explicitly allowed.
# Creating a test account is the supported extra-user path and is NOT
# a leak — greetd/polkit/sysctl/tmpfiles/ESP-hook are the dangerous ones.
# Plymouth in mkinitcpio is not checked: the host may already use it.
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
        done <<<"$gated_hits"
    fi
else
    echo "  (gated-state checks skipped: --allow-gated)"
fi

if id devuser >/dev/null 2>&1; then
    ok "devuser account exists (optional test user; not a leak)"
else
    ok "devuser account not created yet (optional: sudo install/system/create-devuser.sh)"
fi

# 3. home mtime is advisory when a protected path is set — a live
# account keeps writing caches. Real isolation is checks 1–2.
if [ -n "$PROTECTED" ] && [ -d "$PROTECTED" ]; then
    outside_writes=$(find "$PROTECTED" -maxdepth 2 -newer "$BASELINE" -not -path "$REPO_ROOT*" 2>/dev/null | grep -v "^$PROTECTED\$" || true)
    if [ -z "$outside_writes" ]; then
        ok "no new/modified top-level files under the protected home since baseline"
    else
        printf '\033[33mWARN\033[0m protected home has changed since baseline (expected on a live account); not a leak unless a symlink/gated check failed\n'
    fi
fi

if [ "$fail" -eq 0 ]; then
    echo
    echo "Isolation check passed."
else
    echo
    echo "Isolation check FAILED — see above." >&2
    exit 1
fi
