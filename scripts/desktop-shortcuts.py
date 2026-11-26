#!/usr/bin/env python3
"""Desktop shortcuts and launcher icons the theme never picks up.

Steam, Lutris and the same kind of launcher write an icon after the
shell has started, or they only keep a cover picture. The theme list
from startup cannot paint that, so this prints the file path.
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
EXTS = (".png", ".svg", ".xpm", ".jpg", ".jpeg", ".webp")
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


def _lutris_cover_dir() -> Path | None:
    override = os.environ.get("MODERN_LUTRIS_COVER", "").strip()
    if override:
        return Path(override)
    # A test icon root must not pick up the real library.
    if os.environ.get("MODERN_ICON_ROOTS", "").strip():
        return None
    path = _home() / ".local/share/lutris/coverart"
    return path if path.is_dir() else None


def _lutris_cover(name: str) -> str:
    if not name.startswith("lutris_"):
        return ""
    folder = _lutris_cover_dir()
    if folder is None:
        return ""
    slug = name[len("lutris_"):]
    for ext in EXTS:
        path = folder / f"{slug}{ext}"
        if path.is_file():
            return str(path)
    return ""


def _steam_library_roots() -> list[Path]:
    override = os.environ.get("MODERN_STEAM_LIBRARY", "").strip()
    if override:
        return [Path(override)]
    # A fixture icon root must not read the real Steam library.
    if os.environ.get("MODERN_ICON_ROOTS", "").strip():
        return []
    home = _home()
    return [
        home / ".local/share/Steam/appcache/librarycache",
        home / ".steam/steam/appcache/librarycache",
        home / ".steam/root/appcache/librarycache",
    ]


def _steam_library_icon(appid: str) -> str:
    # Steam's desktop shortcut asks for steam_icon_<id>.png. That file is
    # written once into the user theme. The square picture in the library
    # cache is still there when the png is not.
    if not appid.isdigit():
        return ""
    skip = {
        "library_header.jpg",
        "library_hero.jpg",
        "library_hero_blur.jpg",
        "library_capsule.jpg",
        "logo.png",
        "logo.jpg",
    }
    for root in _steam_library_roots():
        folder = root / appid
        if not folder.is_dir():
            continue
        direct = [
            path for path in folder.iterdir()
            if path.is_file()
            and path.suffix.lower() in EXTS
            and path.name.lower() not in skip
        ]
        if not direct:
            continue
        direct.sort(key=lambda path: path.stat().st_size)
        return str(direct[0])
    return ""


def _webapp_profiles() -> list[Path]:
    override = os.environ.get("MODERN_WEBAPP_DIR", "").strip()
    if override:
        return [Path(override)]
    if os.environ.get("MODERN_ICON_ROOTS", "").strip():
        return []
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(_home() / ".config")))
    browser = config / "vivaldi"
    if not browser.is_dir():
        return []
    return [path for path in browser.iterdir() if path.is_dir()]


def _largest_png(folder: Path) -> str:
    if not folder.is_dir():
        return ""
    best = ""
    best_n = -1
    for path in folder.iterdir():
        if not path.is_file() or path.suffix.lower() != ".png":
            continue
        n = int(path.stem) if path.stem.isdigit() else 0
        if n >= best_n:
            best_n = n
            best = str(path)
    return best


def _webapp_icon(name: str) -> str:
    # vivaldi-<app id>-<profile>. The picture stays in the browser profile.
    prefix = "vivaldi-"
    if not name.startswith(prefix):
        return ""
    rest = name[len(prefix):]
    if "-" not in rest:
        return ""
    appid, profile = rest.rsplit("-", 1)
    if not appid or not profile or "/" in appid or "/" in profile:
        return ""
    for prof in _webapp_profiles():
        if prof.name.lower() != profile.lower() and os.environ.get("MODERN_WEBAPP_DIR", "").strip() == "":
            continue
        found = _largest_png(prof / "Web Applications" / "Manifest Resources" / appid / "Icons")
        if found:
            return found
    return ""


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
    if stem.startswith("steam_icon_") and stem[11:].isdigit():
        found = _steam_library_icon(stem[11:])
        if found:
            return found
    found = _webapp_icon(stem)
    if found:
        return found
    return _lutris_cover(stem)


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


def _user_icon_root(root: Path) -> bool:
    if os.environ.get("MODERN_ICON_ROOTS", "").strip():
        return True
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(_home() / ".local/share")))
    try:
        return root.resolve().is_relative_to((data_home / "icons").resolve())
    except OSError:
        return False


def _index_hicolor(roots: list[Path], icons: dict[str, str]) -> None:
    # Names already in the icon theme stay there. Launcher icons live in
    # the user hicolor tree, which the running theme does not rescan.
    rank = {size: i for i, size in enumerate(SIZES)}
    found: dict[str, tuple[int, str]] = {}
    for root in roots:
        hicolor = root / "hicolor"
        if not hicolor.is_dir():
            continue
        user = _user_icon_root(root)
        for size in SIZES:
            folder = hicolor / size / "apps"
            if not folder.is_dir():
                continue
            for path in folder.iterdir():
                if not path.is_file() or path.suffix.lower() not in EXTS:
                    continue
                stem = path.stem
                steam = stem.startswith("steam_icon_") and stem[11:].isdigit()
                if not user and not steam:
                    continue
                prev = found.get(stem)
                if prev is None or rank.get(size, 99) < prev[0]:
                    found[stem] = (rank.get(size, 99), str(path))
    for stem, (_, path) in found.items():
        icons.setdefault(stem, path)
    for root in _steam_library_roots():
        if not root.is_dir():
            continue
        for child in root.iterdir():
            if not child.is_dir() or not child.name.isdigit():
                continue
            key = "steam_icon_" + child.name
            if key in icons:
                continue
            path = _steam_library_icon(child.name)
            if path:
                icons[key] = path
    for prof in _webapp_profiles():
        apps = prof / "Web Applications" / "Manifest Resources"
        if not apps.is_dir():
            continue
        for child in apps.iterdir():
            if not child.is_dir():
                continue
            key = "vivaldi-" + child.name + "-" + prof.name
            if key in icons:
                continue
            path = _largest_png(child / "Icons")
            if path:
                icons[key] = path


def _index_lutris(icons: dict[str, str]) -> None:
    folder = _lutris_cover_dir()
    if folder is None or not folder.is_dir():
        return
    for path in folder.iterdir():
        if not path.is_file() or path.suffix.lower() not in EXTS:
            continue
        # A hicolor png of the same name is the icon; the cover fills the gap.
        icons.setdefault("lutris_" + path.stem, str(path))


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
            # A theme icon of the same name must keep winning. Launcher
            # pictures live outside /usr.
            if icon_name and not icon_name.startswith("/") and not icon_path.startswith("/usr/"):
                icons.setdefault(icon_name, icon_path)
            elif icon_name.startswith("/"):
                icons[icon_path] = icon_path
    _index_hicolor(roots, icons)
    _index_lutris(icons)
    shortcuts.sort(key=lambda row: row["name"].casefold())
    return {"shortcuts": shortcuts, "icons": icons}


def main() -> int:
    json.dump(scan(), sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
