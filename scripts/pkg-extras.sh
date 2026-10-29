#!/usr/bin/env bash
# Optional screenshots for a Store detail page. HTTPS allowlist only;
# never follows a redirect off that host. Cache is local JSON.
# Usage: pkg-extras.sh NAME
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/pkg-name.sh
source "$ROOT/lib/pkg-name.sh"

name="${1:-}"
if [ "$#" -ne 1 ] || ! valid_pkg_name "$name"; then
    printf '%s\n' '{"shots":[],"votes":0,"comments":[]}'
    exit 0
fi

empty='{"shots":[],"votes":0,"comments":[]}'
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/modern/pkg-extras/v2"
cache="$cache_dir/$name.json"
if [ -f "$cache" ] && [ ! -L "$cache" ]; then
    age=999999
    if stat -c %Y "$cache" >/dev/null 2>&1; then
        age=$(($(date +%s) - $(stat -c %Y "$cache")))
    fi
    if [ "$age" -ge 0 ] && [ "$age" -lt 86400 ]; then
        cat "$cache"
        exit 0
    fi
fi

if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' "$empty"
    exit 0
fi

url="https://screenshots.debian.net/json/package/${name}"
raw="$(curl -fsS --proto '=https' --tlsv1.2 --max-time 4 --max-redirs 2 \
    --retry 0 -A 'modern-store/1' -- "$url" 2>/dev/null || true)"
if [ -z "$raw" ]; then
    printf '%s\n' "$empty"
    exit 0
fi

out="$(NAME="$name" python3 -c '
import json, os, sys
from urllib.parse import urlparse

name = os.environ.get("NAME") or ""
host = "screenshots.debian.net"
try:
    data = json.loads(sys.stdin.read() or "{}")
except ValueError:
    data = {}
def allow(u):
    u = str(u or "").strip()
    p = urlparse(u)
    if p.scheme != "https" or p.netloc != host or p.path.startswith("//"):
        return ""
    if any(ch in u for ch in [" ", "\n", "\r", "\\"]):
        return ""
    path = p.path
    for prefix in ("/thumbnail/", "/small/"):
        if path.startswith(prefix):
            path = "/screenshot/" + path[len(prefix):]
            break
    return "https://%s%s" % (host, path)

shots = []
keys = ("screenshot_image_url", "large_image_url", "small_image_url", "url", "thumb_image_url")
for item in data.get("screenshots") or []:
    if not isinstance(item, dict):
        continue
    u = ""
    for key in keys:
        u = allow(item.get(key))
        if u:
            break
    if not u:
        continue
    shots.append(u)
    if len(shots) >= 8:
        break
print(json.dumps({"shots": shots, "votes": 0, "comments": []}, ensure_ascii=False))
' <<<"$raw" || true)"

if [ -z "$out" ]; then
    printf '%s\n' "$empty"
    exit 0
fi
mkdir -p "$cache_dir"
printf '%s\n' "$out" >"$cache"
printf '%s\n' "$out"
