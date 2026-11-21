#!/usr/bin/env bash
# Render the system application icons from install/icons/apps into the
# user's icon theme, recolored from tokens.json so the copies outside
# the shell stay on the active palette. The shell paints the same
# primaryContainer / onPrimaryContainer roles itself.
# The templates carry the shipped default wallpaper's palette and are
# never written: the output is a regular file per icon, replacing any
# older stow symlink, so a wallpaper change never touches the repo.
set -euo pipefail

TEMPLATES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/icons/apps"
TOKENS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/tokens.json"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"

if [ ! -d "$TEMPLATES" ] || ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi
mkdir -p "$ICONS"

TEMPLATES="$TEMPLATES" TOKENS="$TOKENS" ICONS="$ICONS" python3 - <<'PY'
import json, os, re
from pathlib import Path

plate = ink = ""
try:
    color = json.load(open(os.environ["TOKENS"], encoding="utf-8")).get("color") or {}
    plate = str(color.get("primaryContainer") or "")
    ink = str(color.get("onPrimaryContainer") or "")
except (OSError, ValueError):
    pass
recolor = plate.startswith("#") and ink.startswith("#")
out_dir = Path(os.environ["ICONS"])
for src in sorted(Path(os.environ["TEMPLATES"]).glob("modern-*.svg")):
    text = src.read_text(encoding="utf-8")
    fills = list(re.finditer(r'fill="#[0-9A-Fa-f]{3,8}"', text))
    if recolor and len(fills) >= 2:
        parts, last = [], 0
        for i, match in enumerate(fills):
            parts.append(text[last:match.start()])
            parts.append(f'fill="{plate if i == 0 else ink}"')
            last = match.end()
        parts.append(text[last:])
        text = "".join(parts)
    dest = out_dir / src.name
    tmp = out_dir / f".{src.name}.tmp"
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, dest)
PY

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$(dirname "$(dirname "$ICONS")")" >/dev/null 2>&1 || true
fi
