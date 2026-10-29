#!/usr/bin/env bash
# Unprivileged coverage for calendar-fetch.sh. Never talks to CalDAV.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-calendar-fetch: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-calendar-fetch: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/calendar-fetch.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-cal-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export MODERN_CONFIG_JSON="$TMP/config.json"
export MODERN_SECRETS_JSON="$TMP/secrets.json"

if "$SCRIPT" extra >/dev/null 2>&1; then
    err "rejected extra argv"
else
    ok "rejects extra argv"
fi

printf '%s\n' '{}' >"$MODERN_CONFIG_JSON"
printf '%s\n' '{}' >"$MODERN_SECRETS_JSON"
if [ -z "$("$SCRIPT")" ]; then
    ok "empty config prints nothing"
else
    err "empty should be silent"
fi

printf '%s\n' '{"accounts":{"calendarIcsUrl":"'"$TMP"'/legacy.ics"}}' >"$MODERN_CONFIG_JSON"
printf '%s\n' $'BEGIN:VCALENDAR\nEND:VCALENDAR' >"$TMP/legacy.ics"
out="$("$SCRIPT")"
if printf '%s\n' "$out" | grep -Fq 'BEGIN:VCALENDAR'; then
    ok "legacy file path still loads"
else
    err "legacy: $out"
fi

printf '%s\n' '{"widgets":{"clock":{"calendarProvider":"proton"}}}' >"$MODERN_CONFIG_JSON"
printf '%s\n' '{"calendar":{"icsUrl":"'"$TMP"'/secret.ics"}}' >"$MODERN_SECRETS_JSON"
printf '%s\n' $'BEGIN:VCALENDAR\nPRODID:secret\nEND:VCALENDAR' >"$TMP/secret.ics"
out="$("$SCRIPT")"
if printf '%s\n' "$out" | grep -Fq 'PRODID:secret'; then
    ok "secrets iCal path wins over empty config URL"
else
    err "secrets: $out"
fi

export MODERN_TEST_FIXTURE=1
export MODERN_CALENDAR_ICS=$'BEGIN:VCALENDAR\nFIXTURE\nEND:VCALENDAR'
out="$("$SCRIPT")"
if printf '%s\n' "$out" | grep -Fq 'FIXTURE'; then
    ok "fixture mode"
else
    err "fixture: $out"
fi
unset MODERN_TEST_FIXTURE MODERN_CALENDAR_ICS

if python3 -m py_compile "$ROOT/scripts/lib/calendar-caldav.py"; then
    ok "caldav helper compiles"
else
    err "calendar-caldav.py"
fi

if grep -F 'Paths.script("calendar-fetch.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Calendar.qml" >/dev/null \
    && grep -Fq 'singleton CalendarAccount' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/qmldir" \
    && grep -Fq 'CalendarConnect' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/bar/ClockForm.qml" \
    && ! grep -Fq 'CalendarFeed' \
    "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/privacy/Section.qml"; then
    ok "Date and time owns calendar connect; Privacy does not"
else
    err "calendar UI wiring"
fi

if grep -Fq '"clock": "Date and time"' \
    "$ROOT/stow/modern/.config/modern/translations/en.json" \
    && grep -Fq '"clock": "Datum und Uhrzeit"' \
    "$ROOT/stow/modern/.config/modern/translations/de.json"; then
    ok "Date and time labels"
else
    err "bar.clock labels"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-calendar-fetch: ok\n'
