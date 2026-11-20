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

rc_of() { local rc=0; "$@" >"$TMP/out" 2>/dev/null || rc=$?; printf '%s' "$rc"; }

printf '%s\n' '<html><body>Google Calendar</body></html>' >"$TMP/page.html"
printf '%s\n' '{"calendar":{"icsUrl":"'"$TMP"'/page.html"}}' >"$MODERN_SECRETS_JSON"
rc="$(rc_of "$SCRIPT")"
if [ "$rc" = 11 ]; then
    ok "a calendar web page instead of its iCal link is reported as not a calendar"
else
    err "web page link exit $rc, want 11"
fi

rc="$(rc_of env MODERN_CAL_CHECK=1 MODERN_CAL_PROVIDER=google MODERN_CAL_URL="$TMP/secret.ics" "$SCRIPT")"
if [ "$rc" = 0 ] && grep -Fq 'PRODID:secret' "$TMP/out"; then
    ok "check mode reads an unsaved link from the environment"
else
    err "check mode link exit $rc"
fi

if grep -Fq -- '--password' "$SCRIPT" || grep -Fq -- '"--password"' "$ROOT/scripts/lib/calendar-caldav.py"; then
    err "the Apple password must not travel on argv"
else
    ok "the Apple password stays off argv"
fi

port_file="$TMP/port"
python3 "$ROOT/scripts/lib/fake-caldav.py" me@icloud.com abcd-efgh-ijkl-mnop >"$port_file" &
srv=$!
trap 'kill "$srv" 2>/dev/null || true; cleanup' EXIT
for _ in $(seq 1 50); do
    [ -s "$port_file" ] && break
    sleep 0.05
done
MODERN_CALDAV_URL="http://127.0.0.1:$(cat "$port_file")/"
export MODERN_CALDAV_URL
apple() { rc_of env MODERN_CAL_CHECK=1 MODERN_CAL_PROVIDER=apple MODERN_CAL_USER=me@icloud.com MODERN_CAL_PASSWORD="$1" "$SCRIPT"; }

rc="$(apple 'abcd efgh ijkl mnop')"
if [ "$rc" = 0 ] && grep -Fq 'SUMMARY:Dentist' "$TMP/out"; then
    ok "iCloud: redirect, double challenge and a refusing Reminders list still load events"
else
    err "iCloud fetch exit $rc: $(cat "$TMP/out")"
fi
rc="$(apple wrong-password)"
if [ "$rc" = 10 ]; then
    ok "iCloud: a refused app password exits 10"
else
    err "iCloud wrong password exit $rc, want 10"
fi
kill "$srv" 2>/dev/null || true
wait "$srv" 2>/dev/null || true
rc="$(apple abcd-efgh-ijkl-mnop)"
if [ "$rc" = 12 ]; then
    ok "iCloud: an unreachable server exits 12"
else
    err "iCloud offline exit $rc, want 12"
fi
unset MODERN_CALDAV_URL

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

svc="$ROOT/stow/shell/.config/quickshell/modern/Services/Calendar.qml"
if grep -Fq 'MODERN_CAL_PASSWORD' "$svc" \
    && grep -Fq 'CalendarAccount.saveApple' "$svc" \
    && ! grep -Fq 'loadFailed' "$svc"; then
    ok "connect checks the calendar before saving it"
else
    err "Calendar.check must load before saving"
fi

if grep -Fq '"clock": "Date and time"' \
    "$ROOT/stow/modern/.config/modern/translations/en.json" \
    && grep -Fq '"clock": "Datum und Uhrzeit"' \
    "$ROOT/stow/modern/.config/modern/translations/de.json" \
    && grep -Fq 'function reopenAt' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/Settings.qml" \
    && grep -Fq 'Settings.reopenAt("bar", "clock")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/CalendarAccount.qml"; then
    ok "Date and time labels"
else
    err "bar.clock labels"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-calendar-fetch: ok\n'
