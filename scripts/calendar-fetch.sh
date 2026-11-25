#!/usr/bin/env bash
# Print ICS for Services/Calendar. Proton/Google (and Apple shared
# calendars): private iCal link in secrets.json. Apple ID: CalDAV with an
# app-specific password. Never prints credentials and never puts one on
# an argv; curl reads the link from stdin.
#
# MODERN_CAL_CHECK=1 tests a calendar before Settings saves it: provider,
# link, Apple ID and password then come from MODERN_CAL_PROVIDER,
# MODERN_CAL_URL, MODERN_CAL_USER and MODERN_CAL_PASSWORD.
#
# Exit: 0 ok, 10 credentials or link refused, 11 not a calendar link,
# 12 server unreachable, 1 anything else.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${MODERN_CONFIG_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"
SECRETS="${MODERN_SECRETS_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/secrets.json}"
EXIT_AUTH=10
EXIT_NOT_CALENDAR=11
EXIT_OFFLINE=12

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    printf '%s\n' "Usage: calendar-fetch.sh"
    exit 0
fi
if [ $# -ne 0 ]; then
    printf '%s\n' "Usage: calendar-fetch.sh" >&2
    exit 2
fi

if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
    printf '%s\n' "${MODERN_CALENDAR_ICS:-BEGIN:VCALENDAR
END:VCALENDAR}"
    exit 0
fi

jq_str() {
    local file="$1" expr="$2"
    if [ -f "$file" ] && command -v jq >/dev/null 2>&1; then
        jq -r "$expr" "$file" 2>/dev/null || true
    fi
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    printf '%s' "${s%"${s##*[![:space:]]}"}"
}

if [ "${MODERN_CAL_CHECK:-}" = "1" ]; then
    provider="${MODERN_CAL_PROVIDER:-}"
    url="${MODERN_CAL_URL:-}"
    account="${MODERN_CAL_USER:-}"
    pass="${MODERN_CAL_PASSWORD:-}"
else
    provider="$(jq_str "$CFG" '.widgets.clock.calendarProvider // empty')"
    account="$(jq_str "$SECRETS" '.calendar.appleAccount // empty')"
    [ -n "$account" ] || account="$(jq_str "$CFG" '.widgets.clock.calendarAccount // empty')"
    pass="$(jq_str "$SECRETS" '.calendar.applePassword // empty')"
    url="$(jq_str "$SECRETS" '.calendar.icsUrl // empty')"
    [ -n "$url" ] || url="$(jq_str "$CFG" '.accounts.calendarIcsUrl // empty')"
fi
url="$(trim "$url")"

if [ "$provider" = "apple" ] && [ -n "$pass" ]; then
    CALDAV_PASSWORD="$pass" exec python3 "$HERE/lib/calendar-caldav.py" --user "$account" \
        --url "${MODERN_CALDAV_URL:-https://caldav.icloud.com/}"
fi

[ -n "$url" ] || exit 0
case "$url" in
    webcal://*) url="https://${url#webcal://}" ;;
    webcals://*) url="https://${url#webcals://}" ;;
esac

if [[ "$url" == http://* || "$url" == https://* ]]; then
    body="$(mktemp "${TMPDIR:-/tmp}/modern-cal-XXXXXX")"
    trap 'rm -f "$body"' EXIT
    esc="${url//\\/\\\\}"
    esc="${esc//\"/\\\"}"
    rc=0
    code="$(printf 'url = "%s"\n' "$esc" \
        | curl -sSL --max-time 20 --config - -o "$body" -w '%{http_code}' 2>/dev/null)" || rc=$?
    case "$rc" in
        0) ;;
        6 | 7 | 28 | 35 | 52 | 56) exit "$EXIT_OFFLINE" ;;
        3) exit "$EXIT_NOT_CALENDAR" ;;
        *) exit 1 ;;
    esac
    case "$code" in
        401 | 403) exit "$EXIT_AUTH" ;;
        404 | 410) exit "$EXIT_NOT_CALENDAR" ;;
        2??) ;;
        *) exit 1 ;;
    esac
    # A calendar's web page (not its iCal link) answers 200 with HTML.
    grep -q 'BEGIN:VCALENDAR' "$body" || exit "$EXIT_NOT_CALENDAR"
    cat -- "$body"
    exit 0
fi

if [[ "$url" == ~/* ]]; then
    url="${HOME}${url:1}"
fi
if [ -f "$url" ]; then
    grep -q 'BEGIN:VCALENDAR' "$url" || exit "$EXIT_NOT_CALENDAR"
    cat -- "$url"
    exit 0
fi
exit "$EXIT_NOT_CALENDAR"
