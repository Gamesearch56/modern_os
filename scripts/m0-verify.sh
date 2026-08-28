#!/usr/bin/env bash
# M0 verification checklist. Confirms the daily-drivable artifacts exist
# and isolation still holds. Live Hyprland/devuser login is printed as a
# manual step — this environment cannot log into a graphical session.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok() { printf '  [ok] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*" >&2; FAIL=1; }

printf 'M0 verify\n'

[ -x "$ROOT/install/install.sh" ] && ok "install.sh executable" || bad "install.sh missing"
[ -f "$ROOT/stow/hypr/.config/hypr/hyprland.lua" ] && ok "hyprland.lua" || bad "hyprland.lua missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/shell.qml" ] && ok "shell.qml" || bad "shell.qml missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/Module.qml" ] && ok "Bar module" || bad "Bar missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Launcher/Module.qml" ] && ok "Launcher module" || bad "Launcher missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/PowerMenu/Module.qml" ] && ok "PowerMenu module" || bad "PowerMenu missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Cheatsheet/Module.qml" ] && ok "Cheatsheet module" || bad "Cheatsheet missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/audio/Widget.qml" ] && ok "audio widget" || bad "audio widget missing"
[ -f "$ROOT/stow/shell/.config/quickshell/modern/Modules/Bar/widgets/media/Widget.qml" ] && ok "media widget" || bad "media widget missing"
[ -f "$ROOT/scripts/theme-apply.sh" ] && ok "theme-apply.sh" || bad "theme-apply.sh missing"
[ -f "$ROOT/docs/CURSOR-SETUP.md" ] && ok "CURSOR-SETUP.md" || bad "CURSOR-SETUP.md missing"

"$ROOT/scripts/lint-layers.sh" && ok "lint-layers" || bad "lint-layers failed"
"$ROOT/scripts/check-isolation.sh" && ok "isolation" || bad "isolation failed"

if [ -x "$ROOT/install/install.sh" ]; then
    "$ROOT/install/install.sh" --dry-run --profile m0 >/dev/null && ok "install.sh --dry-run --profile m0" || bad "install dry-run failed"
fi

printf '\nManual (on devuser, graphical session via start-hyprland):\n'
printf '  1. bar visible on every monitor\n'
printf '  2. SUPER+Space launcher; SUPER+M power menu; SUPER+K cheatsheet\n'
printf '  3. scroll volume on the audio pill; media controls with Spotify\n'
printf '  4. Vivaldi and Cursor launch; wallpaper-driven colors after theme-apply.sh\n'

if [ "$FAIL" -ne 0 ]; then
    printf '\nM0 verify: FAILED\n' >&2
    exit 1
fi
printf '\nM0 verify: ok\n'
exit 0
