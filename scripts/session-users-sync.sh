#!/usr/bin/env bash
# Snapshot human login names and faces for the greeter select.
set -euo pipefail

SHARED="${MODERN_SESSION_DIR:-/var/lib/modern/session}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$HERE/../install/system/greetd/list-users.py"
[ -d "$SHARED" ] || exit 0
[ -f "$LIST" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

tmp="$(mktemp --suffix=.json -p "$SHARED" tmp.XXXXXX)"
if python3 "$LIST" >"$tmp"; then
    chmod a+r "$tmp" || true
    mv -f "$tmp" "$SHARED/users.json"
else
    rm -f "$tmp"
    exit 1
fi

export MODERN_SESSION_DIR="$SHARED"
python3 - <<'PY' || true
import json
import os
import shutil

shared = os.environ.get("MODERN_SESSION_DIR", "/var/lib/modern/session")
faces = os.path.join(shared, "faces")
os.makedirs(faces, exist_ok=True)
path = os.path.join(shared, "users.json")
try:
    with open(path, encoding="utf-8") as f:
        users = json.load(f)
except (OSError, json.JSONDecodeError):
    raise SystemExit(0)
if not isinstance(users, list):
    raise SystemExit(0)
keep = set()
for u in users:
    if not isinstance(u, dict):
        continue
    login = str(u.get("value") or "")
    if not login or "/" in login or "\\" in login or login in (".", ".."):
        continue
    keep.add(login)
    home = str(u.get("home") or "")
    dest = os.path.join(faces, login)
    cands = []
    if home.startswith("/"):
        cands.append(os.path.join(home, ".face"))
        cands.append(os.path.join(home, ".face.icon"))
    cands.append(os.path.join("/var/lib/AccountsService/icons", login))
    copied = False
    for src in cands:
        if os.path.isfile(src) and os.access(src, os.R_OK):
            shutil.copyfile(src, dest)
            os.chmod(dest, 0o644)
            copied = True
            break
    if not copied and os.path.isfile(dest):
        os.remove(dest)
for name in os.listdir(faces):
    stale = os.path.join(faces, name)
    if name not in keep and os.path.isfile(stale):
        os.remove(stale)
PY
chmod a+rX "$SHARED/faces" 2>/dev/null || true
find "$SHARED/faces" -type f -exec chmod a+r {} + 2>/dev/null || true
