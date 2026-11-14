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

# Last-used login must still exist. A deleted account here makes the
# next sign-in attempt use that name.
if [ -f "$SHARED/default-user" ]; then
    remembered="$(tr -d '\n' <"$SHARED/default-user")"
    if [ -n "$remembered" ] && ! jq -e --arg u "$remembered" 'map(.value) | index($u) != null' "$SHARED/users.json" >/dev/null; then
        first="$(jq -r '.[0].value // empty' "$SHARED/users.json")"
        if [ -n "$first" ]; then
            printf '%s\n' "$first" >"$SHARED/default-user"
            chmod 0664 "$SHARED/default-user" 2>/dev/null || true
            chgrp modern "$SHARED/default-user" 2>/dev/null || true
        else
            rm -f "$SHARED/default-user"
        fi
    fi
fi

export MODERN_SESSION_DIR="$SHARED"
python3 - <<'PY' || true
import json
import os
import shutil

shared = os.environ.get("MODERN_SESSION_DIR", "/var/lib/modern/session")
faces = os.path.join(shared, "faces")
os.makedirs(faces, exist_ok=True)
try:
    os.chmod(faces, 0o2775)
except OSError:
    pass
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
