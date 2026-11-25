#!/usr/bin/env bash
# Live ISO: locale archive + xkb filter. Runs beside greetd, not Before it
# (locale-gen blocked the kiosk on a black VT).
set -euo pipefail

need_gen=0
if ! python3 - <<'PY'
import json, subprocess
from pathlib import Path

paths = (
    Path("/usr/lib/modern/installer-locales.json"),
    Path("/etc/modern/installer-locales.json"),
)
data = None
for p in paths:
    if p.is_file():
        data = json.loads(p.read_text(encoding="utf-8"))
        break
if not data:
    raise SystemExit(1)
try:
    archive = subprocess.check_output(["localedef", "--list-archive"], text=True)
except (OSError, subprocess.CalledProcessError):
    archive = ""
archive_l = archive.lower()
for loc in data.get("locales") or []:
    glibc = str(loc.get("glibc") or "").split(".", 1)[0]
    if glibc and glibc.lower() not in archive_l:
        raise SystemExit(1)
PY
then
    need_gen=1
fi
if [ "$need_gen" -eq 1 ]; then
    locale-gen >/dev/null 2>&1 || true
fi
if command -v python3 >/dev/null 2>&1; then
    python3 /usr/lib/modern/live-xkb-filter.py || true
fi
