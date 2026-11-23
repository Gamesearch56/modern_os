#!/usr/bin/env python3
"""Desktop shortcuts the application scan never sees.

Steam's "create desktop shortcut" writes the .desktop onto the desktop
folder and steam_icon_<id>.png into the user hicolor theme. The shell
icon theme keeps the names it had at startup, so a later png paints as
a blank icon. This prints the absolute png path and the shortcut itself.
"""

import json
import os
import shlex
import sys
from pathlib import Path

SIZES = (
    "512x512",
    "256x256",
    "128x128",
    "96x96",
    "64x64",
    "48x48",
    "32x32",
    "24x24",
    "22x22",
    "16x16",
    "scalable",
)
EXTS = (".png", ".svg", ".xpm")
DROP_FIELDS = {
    "%f", "%F", "%u", "%U", "%c", "%k", "%i", "%d", "%D", "%n", "%N", "%v", "%m",
}


def _home() -> Path:
    return Path(os.environ.get("HOME") or str(Path.home()))


def desktop_dir() -> Path:
    override = os.environ.get("MODERN_DESKTOP_DIR", "").strip()
    if override:
        return Path(override)
    home = str(_home())
    config = os.environ.get("XDG_CONFIG_HOME", str(_home() / ".config"))
    user_dirs = Path(config) / "user-dirs.dirs"
    if user_dirs.is_file():
        for line in user_dirs.read_text(errors="replace").splitlines():
            line = line.strip()
            if not line.startswith("XDG_DESKTOP_DIR="):
                continue
            val = line.split("=", 1)[1].strip().strip('"')
            val = val.replace("${HOME}", home).replace("$HOME", home)
            if val and val != home:
                return Path(val)
    env = os.environ.get("XDG_DESKTOP_DIR", "").strip()
    if env and env != home:
        return Path(env)
    return _home() / "Desktop"


def icon_roots() -> list[Path]:
    override = os.environ.get("MODERN_ICON_ROOTS", "").strip()
    if override:
        return [Path(part) for part in override.split(":") if part]
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(_home() / ".local/share")))
    roots = [data_home / "icons"]
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for part in data_dirs.split(":"):
        if part:
            roots.append(Path(part) / "icons")
    return roots


def _unescape(value: str) -> str:
    out = []
    i = 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append({"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}.get(nxt, nxt))
            i += 2
            continue
        out.append(value[i])
        i += 1
    return "".join(out)


def _parse(path: Path) -> dict[str, str]:
    section = ""
    fields: dict[str, str] = {}
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "Desktop Entry" or "=" not in line:
            continue
        key, val = line.split("=", 1)
        fields[key.strip()] = _unescape(val.strip())
    return fields


def _stem(name: str) -> str:
    low = name.lower()
    for ext in EXTS + (".ico",):
        if low.endswith(ext):
            return name[: -len(ext)]
    return name


def _find_icon(name: str, roots: list[Path]) -> str:
    if not name or name.startswith("."):
        return ""
    if name.startswith("file://"):
        name = name[7:]
    if name.startswith("/"):
        return name if os.path.isfile(name) else ""
    stem = _stem(name)
    if not stem or "/" in stem:
        return ""
    for root in roots:
        hicolor = root / "hicolor"
        for size in SIZES:
            for ext in EXTS:
                path = hicolor / size / "apps" / f"{stem}{ext}"
                if path.is_file():
                    return str(path)
    return ""


def _steam_name(exec_line: str) -> str:
    marker = "rungameid/"
    at = exec_line.find(marker)
    if at < 0:
        return ""
    digits = []
    for ch in exec_line[at + len(marker):]:
        if not ch.isdigit():
            break
        digits.append(ch)
    if not digits:
        return ""
    return "steam_icon_" + "".join(digits)


def _argv(exec_line: str) -> list[str]:
    try:
        parts = shlex.split(exec_line, posix=True)
    except ValueError:
        parts = exec_line.split()
    return [part for part in parts if part not in DROP_FIELDS and not part.startswith("%")]


def _index_steam(roots: list[Path], icons: dict[str, str]) -> None:
    rank = {size: i for i, size in enumerate(SIZES)}
    found: dict[str, tuple[int, str]] = {}
    for root in roots:
        hicolor = root / "hicolor"
        if not hicolor.is_dir():
            continue
        for size in SIZES:
            folder = hicolor / size / "apps"
            if not folder.is_dir():
                continue
            for png in folder.glob("steam_icon_*.png"):
                prev = found.get(png.stem)
                if prev is None or rank[size] < prev[0]:
                    found[png.stem] = (rank[size], str(png))
    for stem, (_, path) in found.items():
        icons.setdefault(stem, path)


def _truthy(value: str) -> bool:
    return value.strip().lower() == "true"


def scan() -> dict:
    roots = icon_roots()
    desk = desktop_dir()
    shortcuts = []
    icons: dict[str, str] = {}
    if desk.is_dir() and desk != _home():
        for path in sorted(desk.glob("*.desktop")):
            if path.name.startswith("."):
                continue
            fields = _parse(path)
            kind = fields.get("Type", "Application") or "Application"
            if kind != "Application" or _truthy(fields.get("NoDisplay", "")) or _truthy(fields.get("Hidden", "")):
                continue
            argv = _argv(fields.get("Exec", ""))
            if not argv:
                continue
            icon_name = _stem(fields.get("Icon", ""))
            if not icon_name:
                icon_name = _steam_name(fields.get("Exec", ""))
            icon_path = _find_icon(icon_name, roots)
            sid = path.stem
            shortcuts.append({
                "id": sid,
                "name": fields.get("Name") or sid,
                "iconName": icon_name,
                "argv": argv,
            })
            if not icon_path:
                continue
            icons[sid] = icon_path
            if icon_name.startswith("steam_icon_") and icon_name[11:].isdigit():
                icons[icon_name] = icon_path
            elif icon_name.startswith("/"):
                icons[icon_path] = icon_path
    _index_steam(roots, icons)
    shortcuts.sort(key=lambda row: row["name"].casefold())
    return {"shortcuts": shortcuts, "icons": icons}


def main() -> int:
    json.dump(scan(), sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
