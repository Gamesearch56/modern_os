#!/usr/bin/env bash
# Recolor the system application icons from tokens.json so the copies
# outside the shell stay on the active palette. The shell paints the
# same primaryContainer / onPrimaryContainer roles itself.
set -euo pipefail

TOKENS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/tokens.json"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"

if [ ! -f "$TOKENS" ] || [ ! -d "$ICONS" ]; then
    exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

TOKENS="$TOKENS" ICONS="$ICONS" python3 - <<'PY'
import json, os, re
from pathlib import Path

tokens = json.load(open(os.environ["TOKENS"], encoding="utf-8"))
color = tokens.get("color") or {}
plate = str(color.get("primaryContainer") or "")
ink = str(color.get("onPrimaryContainer") or "")
if not (plate.startswith("#") and ink.startswith("#")):
    raise SystemExit(0)
root = Path(os.environ["ICONS"])
for path in sorted(root.glob("modern-*.svg")):
    if path.name.endswith("-symbolic.svg"):
        continue
    text = path.read_text(encoding="utf-8")
    fills = list(re.finditer(r'fill="#[0-9A-Fa-f]{3,8}"', text))
    if len(fills) < 2:
        continue
    out = []
    last = 0
    for i, match in enumerate(fills):
        out.append(text[last:match.start()])
        out.append(f'fill="{plate if i == 0 else ink}"')
        last = match.end()
    out.append(text[last:])
    path.write_text("".join(out), encoding="utf-8")
PY

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$(dirname "$(dirname "$ICONS")")" >/dev/null 2>&1 || true
fi
