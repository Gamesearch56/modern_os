#!/usr/bin/env bash
# Render the system application icons from install/icons/apps into the
# user's icon theme, recolored from tokens.json so the copies outside
# the shell stay on the active palette. The shell paints the same
# primaryContainer / onPrimaryContainer roles itself.
# The templates carry the shipped default wallpaper's palette and are
# never written: the output is a regular file per icon, replacing any
# older stow symlink, so a wallpaper change never touches the repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/ensure-dir.sh
source "$ROOT/scripts/lib/ensure-dir.sh"
TEMPLATES="$ROOT/install/icons/apps"
SYMBOLIC="$ROOT/stow/xdg/.local/share/icons/hicolor/scalable/apps"
TOKENS="${XDG_CONFIG_HOME:-$HOME/.config}/modern/tokens.json"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"

if [ ! -d "$TEMPLATES" ] || ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi
ensure_real_dir "$ICONS"
if [ -d "$SYMBOLIC" ]; then
    find "$SYMBOLIC" -maxdepth 1 -name '*-symbolic.svg' -type f -exec cp -f {} "$ICONS/" \;
fi
# Battle.net and anything that reuses its name (the WoW launcher) look
# this file up by name. It lives in the user theme, so a rebuilt theme
# has to put it back.
for _icon_src in \
    "$ROOT/iso/airootfs/usr/lib/modern/battlenet/battlenet.svg" \
    /usr/lib/modern/battlenet/battlenet.svg
do
    if [ -f "$_icon_src" ]; then
        cp -f "$_icon_src" "$ICONS/battlenet.svg"
        break
    fi
done
unset _icon_src
# A cache written when this directory only held the system glyphs hides
# every icon added afterwards. After a restart the shell trusts that
# cache and game tiles stay empty. The directory itself is the list.
rm -f "$(dirname "$(dirname "$ICONS")")/icon-theme.cache"

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

