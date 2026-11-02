#!/usr/bin/env bash
# The polkit agent is restarted when it registered for another login
# session (after a compositor crash), and left alone otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok() { printf 'test-polkit-agent: ok %s\n' "$*"; }
err() { printf 'test-polkit-agent: FAIL %s\n' "$*" >&2; FAIL=1; }

mkdir -p "$TMP/bin" "$TMP/proc/4242"
cat >"$TMP/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALLS"
case "$*" in
    *"show -p MainPID"*) echo 4242 ;;
    *is-active*) exit 0 ;;
esac
exit 0
SH
chmod +x "$TMP/bin/systemctl"
export PATH="$TMP/bin:$PATH" CALLS="$TMP/calls" POLKIT_AGENT_PROC="$TMP/proc"

# shellcheck source=lib/polkit-agent.sh
. "$ROOT/scripts/lib/polkit-agent.sh"
ensure_patched_phylax() { :; }
sleep() { :; }

agent_env() { printf 'USER=me\0XDG_SESSION_ID=%s\0' "$1" >"$TMP/proc/4242/environ"; }

agent_env 1
: >"$CALLS"
XDG_SESSION_ID=5 ensure_polkit_agent
if grep -q '^--user restart phylax.service$' "$CALLS"; then
    ok "an agent left on an ended session is restarted"
else
    err "agent on session 1 must restart for session 5"
fi

agent_env 5
: >"$CALLS"
XDG_SESSION_ID=5 ensure_polkit_agent
if ! grep -q 'restart' "$CALLS"; then
    ok "an agent on this session is left running"
else
    err "agent on the current session must not restart"
fi

printf 'USER=me\0' >"$TMP/proc/4242/environ"
if XDG_SESSION_ID=5 polkit_agent_in_session; then
    ok "an agent without a session id counts as current"
else
    err "unknown agent session must not force a restart"
fi

[ "$FAIL" -eq 0 ] || exit 1
printf 'test-polkit-agent: ok\n'
