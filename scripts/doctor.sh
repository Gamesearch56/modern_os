#!/usr/bin/env bash
# Health check for a modern_os checkout and the account that would
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
    mode="$(stat -c %a "$SECRETS" 2>/dev/null || echo "?")"
    if [ "$mode" = 600 ]; then
        ok "secrets.json mode 600"
    else
        warn "secrets.json mode $mode — run: chmod 600 $SECRETS"
    fi
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
# `ufw status` needs root and fails for this account even when the firewall
# is up; the unit and ufw.conf are readable.
if command -v ufw >/dev/null 2>&1; then
    if systemctl is-active --quiet ufw.service 2>/dev/null \
        && grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null; then
        ok "ufw active"
    else
        warn "ufw present but not active"
    fi
else
    warn "ufw not on PATH"
fi

section "extensions"
ext="${XDG_DATA_HOME:-$HOME/.local/share}/modern/extensions"
if [ -d "$ext" ]; then
    warn "extensions folder present — this system is modded and unsupported"
else
    ok "no extensions folder"
fi

section "user units"
if pgrep -u "$USER" -x qs >/dev/null 2>&1 || pgrep -u "$USER" -f 'qs -c modern' >/dev/null 2>&1; then
    ok "qs -c modern is running as a Hyprland child (modern-shell.service stays disabled on TTY sessions)"
elif systemctl --user is-enabled modern-shell.service >/dev/null 2>&1; then
    ok "modern-shell.service enabled"
else
    warn "neither qs nor modern-shell.service is running (start Hyprland via start-hyprland)"
fi
if command -v phylax >/dev/null 2>&1; then
    ok "phylax on PATH"
else
    warn "phylax missing — yay -S phylax-git (install/manifests/10-desktop.aur.txt)"
fi
if systemctl --user is-active phylax.service >/dev/null 2>&1; then
    ok "phylax.service is active"
else
    warn "phylax.service is not active — pkexec prompts will not render (systemctl --user reset-failed phylax.service && systemctl --user start phylax.service)"
fi
if [ -x "${HOME}/.local/bin/phylax" ]; then
    ok "patched phylax in ~/.local/bin (session-user Confirm)"
else
    warn "patched Phylax missing (~/.local/bin/phylax) — AUR phylax Confirm uses the first wheel user; run scripts/build-phylax.sh"
fi
if systemctl --user is-active hyprpolkitagent.service >/dev/null 2>&1; then
    warn "hyprpolkitagent.service is still active — stop it so only Phylax registers as the polkit agent"
fi
PHYLAX_CSS="${XDG_CONFIG_HOME:-$HOME/.config}/phylax/style.css"
if [ -f "$PHYLAX_CSS" ]; then
    ok "phylax/style.css present (polkit dialog chrome)"
else
    warn "phylax/style.css missing — run scripts/theme-apply.sh so the password prompt matches overlay chrome"
fi
# rules.d is root:polkitd 0750, so from this account a present file looks
# missing.
if [ ! -x /etc/polkit-1/rules.d ] || [ ! -r /etc/polkit-1/rules.d ]; then
    printf '  --    greeter polkit rules not checked (/etc/polkit-1/rules.d is readable by root only)\n'
elif [ -f /etc/polkit-1/rules.d/50-modern-greeter.rules ]; then
    ok "greeter polkit rules present (login restart/shutdown)"
else
    warn "missing /etc/polkit-1/rules.d/50-modern-greeter.rules — login power actions need greetd_apply / install.sh"
fi
STYLE_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/application-style.conf"
if [ -f "$STYLE_CONF" ]; then
    ok "application-style.conf present (hyprland-qt-support radii)"
else
    warn "application-style.conf missing — run scripts/theme-apply.sh so hypr Qt Quick apps get MD3 radii"
fi

section "PATH tools"
for bin in jq matugen quickshell hyprland-dialog; do
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$bin on PATH"
    elif [ "$bin" = hyprland-dialog ]; then
        warn "hyprland-dialog not on PATH — pacman -S hyprland-guiutils (15s login overlay otherwise)"
    else
        warn "$bin not on PATH"
    fi
done
# qs is the usual Quickshell CLI wrapper on Arch
if command -v qs >/dev/null 2>&1; then
    ok "qs on PATH"
fi

section "theme packages (system-wide; missing icons look like a broken texture)"
if command -v pacman >/dev/null 2>&1; then
    for pkg in papirus-icon-theme bibata-cursor-theme qt6-svg inter-font ttf-jetbrains-mono-nerd; do
        if pacman -Qq "$pkg" >/dev/null 2>&1 || pacman -Qq "${pkg}-bin" >/dev/null 2>&1; then
            ok "$pkg installed"
        else
            warn "$pkg not installed (install.sh --profile m0, or pacman -S $pkg)"
        fi
    done
fi

section "isolation"
PROTECTED="${MODERN_PROTECT_HOME:-}"
PROTECTED="${PROTECTED%/}"
if [ -z "$PROTECTED" ]; then
    ok "live-home guard idle (MODERN_PROTECT_HOME unset)"
elif [ "$HOME" = "$PROTECTED" ]; then
    warn "HOME is the protected path ($HOME) — pass --target to install.sh, or --allow-live-home if this account should own the desktop"
    ok "install.sh will refuse this home unless --allow-live-home is passed"
else
    ok "HOME=$HOME is not the protected path ($PROTECTED)"
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
