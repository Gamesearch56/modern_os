#!/usr/bin/env bash
# Guardrails along boot → login → lock → shutdown that a refactor could
# quietly drop: the greeter never stores password details or resends the
# password, the lock reports compositor confirmation, power actions log
# and surface refusals, and every session start leaves a log header.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-session-safety: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-session-safety: ok %s\n' "$*"; }

QML="$ROOT/stow/shell/.config/quickshell/modern"
AUTH="$ROOT/stow/greeter/.config/quickshell/greeter/GreetdAuth.qml"
GREETD="$ROOT/install/system/greetd"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-session-safety-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if ! grep -q 'pendingLen' "$AUTH" \
    && grep -Fq 'root._answered' "$AUTH" && grep -Fq 'Greetd.cancelSession()' "$AUTH" \
    && grep -Fq 'if (root.launched)' "$AUTH"; then
    ok "greeter: no password length in the trace, one answer, failed launch gives the form back"
else
    err "GreetdAuth.qml lost its password or launch guards"
fi

if grep -Fq 'function secured(): bool' "$QML/Services/Session.qml" \
    && grep -Fq 'Session.reportSecure(secure)' "$QML/Modules/Session/Module.qml" \
    && grep -Fq 'compositor has not confirmed the lock' "$QML/Services/Session.qml" \
    && grep -Fq 'onPamMessage' "$QML/Services/SessionAuth.qml"; then
    ok "lock: compositor confirmation is tracked, logged and exposed; PAM refusals are logged"
else
    err "Session lock confirmation or PAM logging missing"
fi

if grep -Fq 'greeter.log' "$GREETD/hyprland.lua" \
    && tail -n 30 "$GREETD/hyprland.lua" | grep -Fq 'exec qs -c greeter]]' \
    && grep -Fq '== login screen' "$GREETD/kiosk.sh" \
    && grep -Fq '== desktop session' "$GREETD/desktop-session.sh"; then
    ok "login screen and desktop session leave log headers; the greeter starts without a log too"
else
    err "greeter/session logging or its unlogged fallback is missing"
fi

mkdir -p "$TMP/bin"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'echo "$*" >>"$STUB/journal"' >"$TMP/bin/logger"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'case "$1" in start) exit 0 ;; *) exit 1 ;; esac' >"$TMP/bin/systemctl"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$TMP/bin/hyprctl"
chmod +x "$TMP/bin/"*
rc=0
STUB="$TMP" PATH="$TMP/bin:$PATH" "$ROOT/scripts/splash-hold.sh" reboot || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'reboot requested' "$TMP/journal" && grep -q 'reboot refused' "$TMP/journal"; then
    ok "a refused reboot is logged and returns its error"
else
    err "splash-hold reboot refusal: rc=$rc $(cat "$TMP/journal" 2>/dev/null)"
fi
: >"$TMP/journal"
if STUB="$TMP" PATH="$TMP/bin:$PATH" "$ROOT/scripts/splash-hold.sh" logout \
    && grep -q 'logout requested' "$TMP/journal"; then
    ok "logout is logged"
else
    err "splash-hold logout: $(cat "$TMP/journal" 2>/dev/null)"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-session-safety: ok\n'
