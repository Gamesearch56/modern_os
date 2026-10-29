#!/usr/bin/env bash
# Settings speed test: several curl downloads of the Arch ISO so a
# gigabit link can fill. One 8s stream plateaus well below line rate
# (TCP window + handshake counted in curl's average). Fixture env never
# touches the network.
set -euo pipefail

die() { printf 'network-speed: ERROR: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 0 ] || die "usage: network-speed.sh"

if [ "${MODERN_TEST_FIXTURE:-}" = "1" ]; then
    printf '%s\n' '{"speed":125000000,"bytes":1875000000,"time":15,"dns":0.02,"connect":0.05,"code":"200"}'
    exit 0
fi

command -v curl >/dev/null 2>&1 || die "curl missing"

URL="${MODERN_SPEED_URL:-https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso}"
STREAMS=4
CONNECT=8
MAX_TIME=15
WRITE='{"bytes":%{size_download},"time":%{time_total},"dns":%{time_namelookup},"connect":%{time_connect},"start":%{time_starttransfer},"code":"%{http_code}"}'

DIR="$(mktemp -d "${TMPDIR:-/tmp}/modern-netspeed-XXXXXX")"
cleanup() { rm -rf "$DIR"; }
trap cleanup EXIT

start_ns="$(date +%s%N)"
pids=()
i=0
while [ "$i" -lt "$STREAMS" ]; do
    curl -L --tcp-nodelay --connect-timeout "$CONNECT" --max-time "$MAX_TIME" \
        -o /dev/null -s -w "${WRITE}\n" "$URL" >"$DIR/$i.json" || true &
    pids+=("$!")
    i=$((i + 1))
done
for pid in "${pids[@]}"; do
    wait "$pid" || true
done
end_ns="$(date +%s%N)"

python3 - "$DIR" "$start_ns" "$end_ns" <<'PY'
import json, pathlib, sys

d = pathlib.Path(sys.argv[1])
start_ns = int(sys.argv[2])
end_ns = int(sys.argv[3])
elapsed = max((end_ns - start_ns) / 1e9, 0.001)
rows = []
for p in sorted(d.glob("*.json")):
    t = p.read_text(encoding="utf-8").strip()
    if not t:
        continue
    try:
        rows.append(json.loads(t))
    except json.JSONDecodeError:
        continue
bytes_ = sum(max(0, int(float(r.get("bytes") or 0))) for r in rows)
if bytes_ <= 0:
    print("network-speed: ERROR: no bytes downloaded", file=sys.stderr)
    sys.exit(1)
dns = min((float(r.get("dns") or 0) for r in rows), default=0)
connect = min((float(r.get("connect") or 0) for r in rows), default=0)
code = "000"
for r in rows:
    c = str(r.get("code") or "").strip()
    if c and c != "000":
        code = c
        if c == "200" or c == "206":
            break
print(json.dumps({
    "speed": bytes_ / elapsed,
    "bytes": bytes_,
    "time": elapsed,
    "dns": dns,
    "connect": connect,
    "code": code,
}, separators=(",", ":")))
PY
