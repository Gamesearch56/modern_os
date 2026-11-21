#!/usr/bin/env bash
# Unprivileged coverage for Energy lid/button/idle wiring. Never
# suspends, never talks to logind.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-modern-power: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-modern-power: ok %s\n' "$*"; }

MODERN="$ROOT/scripts/modern"
POWER_LUA="$ROOT/stow/hypr/.config/hypr/modules/power.lua"
AUTO="$ROOT/stow/hypr/.config/hypr/modules/autostart.lua"
INHIBIT="$ROOT/scripts/logind-handles.sh"
IDLE="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/power/Idle.qml"
SECTION="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/power/Section.qml"
POWER_QML="$ROOT/stow/shell/.config/quickshell/modern/Services/Power.qml"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"

# shellcheck disable=SC2016
if grep -Fq 'loginctl lock-session' "$MODERN"; then
    err "modern power lock must not use loginctl lock-session"
elif grep -Fq 'exec qs -c modern ipc call session lock' "$MODERN" \
    && grep -Fq 'timeout 2 qs -c modern ipc call session lock' "$MODERN" \
    && grep -Fq 'exec systemctl "$1"' "$MODERN" \
    && grep -Fq 'exec systemctl poweroff' "$MODERN" \
    && grep -Fq 'exec qs -c modern ipc call powermenu open' "$MODERN"; then
    ok "modern power lock/suspend/poweroff/ask"
else
    err "modern power actions missing"
fi

# Stub qs and systemctl: suspend must wait for the confirmed lock, and an
# unconfirmed lock must leave the marker so the next shell starts locked.
STUB="$(mktemp -d "${TMPDIR:-/tmp}/modern-power-XXXXXX")"
trap 'rm -rf "$STUB"' EXIT
mkdir -p "$STUB/bin" "$STUB/run"
cat >"$STUB/bin/qs" <<'EOF'
#!/bin/sh
case "$*" in
    *"session secured"*) cat "$STUB_DIR/secured" 2>/dev/null || echo false ;;
    *"session lock"*) echo lock >>"$STUB_DIR/calls" ;;
esac
EOF
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'echo "systemctl $*" >>"$STUB_DIR/calls"' >"$STUB/bin/systemctl"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$STUB/bin/logger"
chmod +x "$STUB/bin/"*
echo true >"$STUB/secured"
if STUB_DIR="$STUB" XDG_RUNTIME_DIR="$STUB/run" PATH="$STUB/bin:$PATH" "$MODERN" power suspend \
    && [ "$(cat "$STUB/calls")" = "$(printf 'lock\nsystemctl suspend')" ] \
    && [ ! -e "$STUB/run/modern-session-locked" ]; then
    ok "suspend locks first and sleeps once the lock is confirmed"
else
    err "suspend with a confirmed lock: $(cat "$STUB/calls" 2>/dev/null)"
fi
rm -f "$STUB/calls" "$STUB/secured"
if STUB_DIR="$STUB" XDG_RUNTIME_DIR="$STUB/run" PATH="$STUB/bin:$PATH" "$MODERN" power hibernate \
    && grep -Fxq 'systemctl hibernate' "$STUB/calls" \
    && [ "$(cat "$STUB/run/modern-session-locked" 2>/dev/null)" = 1 ]; then
    ok "an unconfirmed lock still sleeps and leaves the locked marker"
else
    err "unconfirmed lock: $(cat "$STUB/calls" 2>/dev/null)"
fi

if grep -Fq 'Paths.script("modern"), "power", "suspend"' "$POWER_QML" \
    && ! grep -Fq '"systemctl", "suspend"' "$POWER_QML"; then
    ok "Power.qml suspends through modern power"
else
    err "Power.qml.suspend must go through modern power suspend"
fi

if grep -Fq 'switch:on:Lid Switch' "$POWER_LUA" \
    && grep -Fq 'switch:off:Lid Switch' "$POWER_LUA" \
    && grep -Fq 'power button' "$POWER_LUA" \
    && grep -Fq 'power lid' "$POWER_LUA" \
    && grep -Fq 'hl.dsp.dpms' "$POWER_LUA" \
    && grep -Fq 'locked = true' "$POWER_LUA"; then
    ok "Hyprland lid and power-button binds"
else
    err "power.lua must bind lid and XF86PowerOff with locked"
fi

if [[ -x "$INHIBIT" ]] \
    && grep -Fq 'handle-lid-switch' "$INHIBIT" \
    && grep -Fq 'handle-power-key' "$INHIBIT" \
    && grep -Fq 'logind-handles.sh' "$AUTO"; then
    ok "session inhibits logind lid/power defaults"
else
    err "logind-handles.sh must start from autostart"
fi

if grep -Fq 'general.idleTimings.dimSec' "$IDLE" \
    && grep -Fq 'general.idleTimings.screenOffSec' "$IDLE" \
    && grep -Fq 'general.idleTimings.lockSec' "$IDLE" \
    && grep -Fq 'general.idleTimings.suspendSec' "$IDLE" \
    && grep -Fq 'power.inhibitOnFullscreen' "$IDLE" \
    && grep -Fq 'power.inhibitOnMedia' "$IDLE"; then
    ok "Energy idle writes timings and inhibit"
else
    err "Idle.qml must write idleTimings and inhibit flags"
fi

if grep -Fq 'power.buttonAction' "$SECTION" \
    && grep -Fq 'power.lidActionAc' "$SECTION" \
    && grep -Fq 'power.lidActionBattery' "$SECTION" \
    && grep -Fq 'Battery.hasBattery' "$SECTION"; then
    ok "Energy power-button and lid rows"
else
    err "Section.qml must write button/lid actions"
fi

if grep -Fq 'ipc", "call", "session", "lock"' "$POWER_QML" \
    && ! grep -Fq 'loginctl lock-session' "$POWER_QML"; then
    ok "Power.qml lock uses session IPC"
else
    err "Power.qml.lock must call session lock, not loginctl"
fi

idle_en="$(jq -r '.settings.fields.idleSuspend' "$EN")"
idle_de="$(jq -r '.settings.fields.idleSuspend' "$DE")"
menu_en="$(jq -r '.powerMenu.suspend' "$EN")"
menu_de="$(jq -r '.powerMenu.suspend' "$DE")"
if [ "$idle_en" = "Sleep" ] && [ "$idle_de" = "Schlafmodus" ] \
    && [ "$menu_en" = "Sleep" ] && [ "$menu_de" = "Schlafmodus" ]; then
    ok "Schlafmodus / Sleep labels"
else
    err "idleSuspend/powerMenu.suspend: en=$idle_en/$menu_en de=$idle_de/$menu_de"
fi

SESSION="$ROOT/stow/shell/.config/quickshell/modern/Services/Session.qml"
if grep -Fq 'modern-session-locked' "$SESSION" \
    && grep -Fq 'blockLoading: true' "$SESSION" \
    && grep -Fq 'allow_session_lock_restore = true' "$ROOT/stow/hypr/.config/hypr/modules/general.lua"; then
    ok "a shell reload or crash while locked comes back locked"
else
    err "lock must survive a shell reload (runtime marker + allow_session_lock_restore)"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-modern-power: ok\n'
