#!/usr/bin/env bash
# Local library totals from a fake Steam folder. No network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$ROOT/scripts/games-library.py"
fail=0
ok() { printf 'ok %s\n' "$1"; }
err() { printf 'not ok %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
apps="$TMP/.local/share/Steam/steamapps"
mkdir -p "$apps" "$TMP/.local/share/Steam/userdata/1/config"
cat >"$apps/appmanifest_10.acf" <<'EOF'
"AppState"
{
  "appid" "10"
  "name" "Example Game"
  "SizeOnDisk" "1073741824"
  "LastPlayed" "1700000000"
}
EOF
cat >"$apps/appmanifest_228980.acf" <<'EOF'
"AppState"
{
  "appid" "228980"
  "name" "Steamworks Common Redistributables"
  "SizeOnDisk" "99"
  "LastPlayed" "1800000000"
}
EOF
printf '%s\n' '"10"' '{' '"Playtime" "120"' '}' >"$TMP/.local/share/Steam/userdata/1/config/localconfig.vdf"

got="$(HOME="$TMP" python3 "$PY")"
python3 - "$got" <<'PY' || err "library totals"
import json, sys
row = json.loads(sys.argv[1])
assert row["installed"] == 1, row
assert row["bytes"] == 1073741824, row
assert row["hours"] == 2, row
assert row["last"] == 1700000000, row
assert row["lastName"] == "Example Game", row
PY
if [[ "$fail" -eq 0 ]]; then
    ok "library totals skip redistributables and sum playtime"
fi
exit "$fail"
