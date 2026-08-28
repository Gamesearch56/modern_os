#!/usr/bin/env bash
# Health check for a modern_dotfile checkout and the account that would
# run it. Never mutates the machine. Exit 0 if only warnings; exit 1 if
# critical repo files are missing (the tree cannot install from here).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WARN=0
CRIT=0

ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; WARN=1; }
crit() { printf '  CRIT  %s\n' "$*"; CRIT=1; }

section() { printf '\n== %s ==\n' "$*"; }

need_repo() {
    local rel="$1"
    if [ -e "$ROOT/$rel" ]; then
        ok "repo $rel"
    else
        crit "missing $rel"
    fi
}

section "repo files"
need_repo "AGENTS.md"
need_repo "install/install.sh"
need_repo "scripts/check-isolation.sh"
need_repo "stow/modern/.config/modern/config.default.json"
need_repo "stow/shell/.config/quickshell/modern/shell.qml"
need_repo "install/hardware.conf.example"

if [ -x "$ROOT/scripts/check-isolation.sh" ] || [ -f "$ROOT/scripts/check-isolation.sh" ]; then
    ok "isolation script present"
else
    crit "scripts/check-isolation.sh missing"
fi

section "optional runtime files (this account)"
TOKENS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/tokens.json"
if [ -f "$TOKENS" ]; then
    ok "tokens.json present"
else
    warn "tokens.json missing (install.sh applies the shipped default wallpaper; or run scripts/theme-apply.sh --wallpaper PATH)"
fi

SECRETS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/secrets.json"
if [ -f "$SECRETS" ]; then
    ok "secrets.json present (gitignored — good)"
else
    warn "secrets.json missing — API tokens will not be available until you create it"
fi

section "disk space"
df -h / /home 2>/dev/null || df -h /

section "backup tools"
if command -v snapper >/dev/null 2>&1; then
    if snapper list-configs >/dev/null 2>&1 && snapper list-configs 2>/dev/null | grep -q .; then
        ok "snapper installed and has configs"
    else
        warn "snapper installed but not configured (see docs/BACKUP.md)"
    fi
else
    warn "snapper not on PATH / not configured"
fi
if command -v restic >/dev/null 2>&1; then
    warn "restic is installed but a repository is not configured here (see docs/BACKUP.md)"
else
    warn "restic not configured (later)"
fi

section "firewall"
if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -qi 'Status: active'; then
        ok "ufw active"
    else
        warn "ufw present but not active"
    fi
else
    warn "ufw not on PATH"
fi

section "user units"
if systemctl --user is-enabled modern-shell.service >/dev/null 2>&1; then
    ok "modern-shell.service enabled"
else
    warn "modern-shell.service not enabled (stow systemd + systemctl --user enable --now)"
fi

section "PATH tools"
for bin in jq matugen quickshell; do
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$bin on PATH"
    else
        warn "$bin not on PATH"
    fi
done
# qs is the usual Quickshell CLI wrapper on Arch
if command -v qs >/dev/null 2>&1; then
    ok "qs on PATH"
fi

section "isolation"
PROTECTED="${MODERN_PROTECT_HOME:-/home/bastianweigand}"
if [ "$HOME" = "$PROTECTED" ]; then
    warn "this shell is the daily-driver account ($HOME) — do not run install.sh without --target /home/devuser"
    ok "install.sh will refuse this home unless --allow-live-home is passed"
else
    ok "HOME=$HOME is not the protected daily-driver path ($PROTECTED)"
fi

echo
if [ "$CRIT" -ne 0 ]; then
    printf 'doctor: CRITICAL — this checkout is incomplete.\n' >&2
    exit 1
fi
if [ "$WARN" -ne 0 ]; then
    printf 'doctor: completed with warnings (machine untouched).\n'
    exit 0
fi
printf 'doctor: all checks passed.\n'
exit 0
