#!/usr/bin/env bash
# scripts/bug-report.sh against a fake home and a fake GitHub API:
# screenshots per monitor, redacted collection that never reads secrets,
# sending (issue + bundle + inline shots), the offline outbox, and the
# not-set-up / refused answers.
# Stub bodies are single-quoted on purpose: they expand when the stub runs.
# ok never fails, so `cond && ok || err` is a real if/else.
# shellcheck disable=SC2016,SC2015
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok() { printf 'test-bug-report: ok %s\n' "$1"; }
err() {
    printf 'test-bug-report: FAIL %s\n' "$1" >&2
    FAIL=1
}

tmp="$(mktemp -d)"
server=""
# shellcheck disable=SC2329
cleanup() {
    [ -z "$server" ] || kill "$server" 2>/dev/null || true
    rm -rf "$tmp"
}
trap cleanup EXIT

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$tmp/bin/$1"
    chmod +x "$tmp/bin/$1"
}

mkdir -p "$tmp/bin" "$tmp/home/.config/modern/keyrings" "$tmp/run/hypr/abc" "$tmp/calls"
export HOME="$tmp/home" USER=alice BUG_REPORT_HOSTNAME=devbox
export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state" XDG_RUNTIME_DIR="$tmp/run"
export PATH="$tmp/bin:$PATH" I18N_LANG=en LANG=C
unset BUG_REPORT_DIR BUG_REPORT_API
SECRET="sekret-value-4711"
printf '{"bugReport":{"githubToken":"tok-%s"}}\n' "$SECRET" >"$XDG_CONFIG_HOME/modern/secrets.json"
printf 'BATTLENET_EXE=%s\n' "$SECRET" >"$XDG_CONFIG_HOME/modern/battlenet.env"
printf '%s\n' "$SECRET" >"$XDG_CONFIG_HOME/modern/keyrings/login.keyring"
printf '{"language":{"ui":"en"},"accounts":{"calendarIcsUrl":"https://cal.test/%s.ics"},"bugReport":{"repo":"owner/reports"}}\n' "$SECRET" \
    >"$XDG_CONFIG_HOME/modern/config.json"
printf 'hypr log line from /home/alice\n' >"$tmp/run/hypr/abc/hyprland.log"

stub hyprctl 'case "$1 $2" in
  "monitors -j") printf "[{\"name\":\"eDP-1\"},{\"name\":\"HDMI-A-1\"}]" ;;
  "clients -j") printf "[{\"class\":\"vivaldi\",\"title\":\"Private chat with Bob\",\"workspace\":{\"name\":\"1\"}}]" ;;
  *) printf "[]" ;;
esac'
stub grim 'for a; do out="$a"; done; printf "JPEG" >"$out"'
stub journalctl 'printf "Nov 03 alice@example.org joined from 192.168.0.5 on devbox\n"
printf "NetworkManager: (wifi) access point '"'"'Cafe Net 5G'"'"' has security\n"
printf "wpa_supplicant: CTRL-EVENT-SSID-TEMP-DISABLED id=0 ssid=\"Home Box\" auth_failures=1\n"'
for s in systemctl coredumpctl lspci lsusb wpctl pactl pw-metadata bluetoothctl nmcli iw rfkill umu-run; do
    stub "$s" 'printf "%s output\n" "$(basename "$0")"'
done
stub notify-send 'printf "%s\n" "$*" >>"'"$tmp"'/calls/notify"'
stub xdg-user-dir 'printf "%s/Downloads\n" "$HOME"'

BR="$ROOT/scripts/bug-report.sh"
REPORTS="$XDG_STATE_HOME/modern/reports"

start_server() {
    [ -z "$server" ] || { kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; }
    rm -f "$tmp/port" "$tmp/gh.log"
    python3 "$ROOT/scripts/lib/fake-github.py" "$tmp/port" "$tmp/gh.log" "$@" &
    server=$!
    local _
    for _ in $(seq 1 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
    BUG_REPORT_API="http://127.0.0.1:$(cat "$tmp/port")"
    export BUG_REPORT_API
}

id="$("$BR" new)"
shots="$("$BR" capture "$id")"
[ "$(jq length <<<"$shots")" = 2 ] && jq -e 'map(.name) | any(test("^HDMI-A-1-[0-9]+\\.jpg$"))' <<<"$shots" >/dev/null \
    && ok "one screenshot per monitor" || err "screenshots: $shots"

files="$("$BR" collect "$id" now)"
dir="$REPORTS/$id/files"
[ -f "$dir/hyprland.txt" ] || err "collection wrote no hyprland.txt"
jq -e 'map(.name) | index("journal-user.txt") and index("config.json") and index("system.txt")' <<<"$files" >/dev/null \
    && ok "collection lists its files" || err "collect: $files"
if grep -rq "$SECRET" "$dir"; then err "a secret reached the report"; else ok "secrets, keyrings and battlenet.env never collected"; fi
if grep -rqE 'alice|devbox|192\.168\.0\.5|example\.org' "$dir"; then err "identity not redacted"; else ok "user, host, mail and IP redacted"; fi
if grep -rqE 'Cafe|Net 5G|Home Box' "$dir"; then err "a Wi-Fi name reached the report"; else ok "Wi-Fi names with spaces are redacted"; fi
if grep -q 'Private chat' "$dir/hyprland.txt"; then err "window titles collected"; else ok "window titles left out"; fi

req='{"title":"Sound drops","description":"Audio stops after resume","categories":["sound"],"when":"now","repeat":"sometimes","files":["system.txt","journal-user.txt"],"shots":["'"$(jq -r '.[] | select(.name | startswith("eDP-1")) | .name' <<<"$shots")"'"]}'

start_server
num="$("$BR" send "$id" "$req")" && [ "$num" = 7 ] && ok "send prints the issue number" || err "send: $num"
jq -se '[.[] | select(.method == "PUT")] | length == 2' "$tmp/gh.log" >/dev/null \
    && ok "bundle and the one ticked screenshot uploaded" || err "uploads: $(cat "$tmp/gh.log")"
jq -se '.[] | select(.path == "/repos/owner/reports/issues") | .body
    | (.labels == ["area:audio"]) and (.body | test("## Steps")) and (.body | test("## Environment"))
      and (.body | test("eDP-1-[0-9]+\\.jpg\\?raw=true")) and (.title | startswith("["))' "$tmp/gh.log" >/dev/null \
    && ok "issue carries label, steps, environment, screenshot and version title" || err "issue: $(tail -1 "$tmp/gh.log")"
jq -se '.[0].auth == "Bearer tok-'"$SECRET"'"' "$tmp/gh.log" >/dev/null && ok "token from secrets.json" || err "auth header"
"$BR" send "$id" >/dev/null \
    && [ "$(jq -s '[.[] | select(.path | endswith("/issues"))] | length' "$tmp/gh.log")" = 1 ] \
    && ok "resend of a sent report files nothing new" || err "resend duplicated"

fetched="$("$ROOT/scripts/report-fetch.sh" 7)"
[ "$fetched" = "$HOME/Downloads/modernos-report-7" ] && [ -f "$fetched/files/system.txt" ] \
    && ok "fetch unpacks the issue bundle into Downloads" || err "fetch: $fetched"

id2="$("$BR" new)"
"$BR" collect "$id2" today >/dev/null
rc=0; BUG_REPORT_API="http://127.0.0.1:9" "$BR" send "$id2" "$req" >/dev/null || rc=$?
[ "$rc" = 20 ] && [ -f "$REPORTS/$id2/queued" ] && ok "offline send is queued" || err "offline rc=$rc"
out="$("$BR" outbox)"
grep -q "^sent $id2 7$" <<<"$out" && [ ! -f "$REPORTS/$id2/queued" ] && ok "outbox sends queued reports" || err "outbox: $out"
[ "$("$BR" status)" = '{"ready":true,"queued":0}' ] && ok "status reports ready, nothing queued" || err "status: $("$BR" status)"

id3="$("$BR" new)"
"$BR" collect "$id3" >/dev/null
start_server refuse
rc=0; "$BR" send "$id3" "$req" >/dev/null || rc=$?
[ "$rc" = 22 ] && ok "refused token answers 22" || err "refused rc=$rc"
printf '{}\n' >"$XDG_CONFIG_HOME/modern/secrets.json"
rc=0; "$BR" send "$id3" "$req" >/dev/null || rc=$?
[ "$rc" = 21 ] && ok "missing token answers 21" || err "no-token rc=$rc"

path="$("$BR" export "$id3")"
tar -tJf "$path" | grep -q 'files/system.txt' && ok "export writes a bundle to Downloads" || err "export: $path"

"$BR" quick sound >/dev/null 2>&1 || true
grep -q "$(jq -r '.bugReport.notSetUp' "$ROOT/stow/modern/.config/modern/translations/en.json")" "$tmp/calls/notify" \
    && ok "quick report without a token exports and notifies" || err "quick: $(cat "$tmp/calls/notify" 2>/dev/null)"

[ "$FAIL" -eq 0 ] && printf 'test-bug-report: all passed\n'
exit "$FAIL"
