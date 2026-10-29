#!/usr/bin/env bash
# Print ICS for Services/Calendar. Proton/Google: private iCal URL in
# secrets.json. Apple: CalDAV with an app-specific password. Never
# prints credentials.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${MODERN_CONFIG_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json}"
SECRETS="${MODERN_SECRETS_JSON:-${XDG_CONFIG_HOME:-$HOME/.config}/modern/secrets.json}"

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

provider="$(jq_str "$CFG" '.widgets.clock.calendarProvider // empty')"
account="$(jq_str "$SECRETS" '.calendar.appleAccount // empty')"
if [ -z "${account:-}" ]; then
    account="$(jq_str "$CFG" '.widgets.clock.calendarAccount // empty')"
fi
ics="$(jq_str "$SECRETS" '.calendar.icsUrl // empty')"
legacy="$(jq_str "$CFG" '.accounts.calendarIcsUrl // empty')"
pass="$(jq_str "$SECRETS" '.calendar.applePassword // empty')"
url="${ics:-}"
if [ -z "$url" ]; then
    url="${legacy:-}"
fi
url="${url#"${url%%[![:space:]]*}"}"
url="${url%"${url##*[![:space:]]}"}"
if [[ "${url}" == webcal://* ]]; then
    url="https://${url#webcal://}"
fi

if [ "${provider}" = "apple" ]; then
    exec python3 "$HERE/lib/calendar-caldav.py" --user "$account" --password "$pass"
fi

if [ -z "$url" ]; then
    exit 0
fi
if [[ "$url" == http://* || "$url" == https://* ]]; then
    exec curl -fsSL --max-time 20 -- "$url"
fi
if [[ "$url" == ~/* ]]; then
    url="${HOME}${url:1}"
fi
if [ -f "$url" ]; then
    cat -- "$url"
    exit 0
fi
exit 1
