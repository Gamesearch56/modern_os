#!/usr/bin/env python3
"""Local game library totals. Steam, Lutris, and Heroic on this PC. No network."""
import json
import os
import re
import sqlite3
from pathlib import Path

HOME = Path(os.environ.get("HOME", "")).expanduser()
SKIP = {"steamworks common redistributables", "proton", "steam linux runtime"}
# Battle.net product ids. WoW Forever is a separate install from retail.
BATTLENET_NAMES = {
    "wowf": "WoW Forever",
    "wow": "World of Warcraft",
    "wow_classic": "WoW Classic",
    "wow_classic_era": "WoW Classic",
    "wow_classic_beta": "WoW Classic",
    "w3": "Warcraft III",
    "d3": "Diablo III",
    "fenris": "Diablo IV",
    "pro": "Overwatch",
    "prometheus": "Overwatch 2",
    "s2": "StarCraft II",
}
WOW_LOGS = {
    "_forever_": "WoW Forever",
    "_retail_": "World of Warcraft",
    "_classic_": "WoW Classic",
    "_classic_era_": "WoW Classic",
    "_classic_beta_": "WoW Classic",
}


def _steam_roots():
    found = []
    seen = set()
    for rel in (".steam/steam", ".steam/root", ".local/share/Steam"):
        path = (HOME / rel).resolve()
        if path.is_dir() and path not in seen:
            seen.add(path)
            found.append(path)
    return found


def _quoted(text, key):
    match = re.search(r'"%s"\s+"([^"]*)"' % re.escape(key), text)
    return match.group(1) if match else ""


def _library_dirs(root):
    dirs = []
    apps = root / "steamapps"
    if apps.is_dir():
        dirs.append(apps)
    vdf = apps / "libraryfolders.vdf"
    if not vdf.is_file():
        return dirs
    for path in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(errors="replace")):
        folder = Path(path.replace("\\\\", "\\")) / "steamapps"
        if folder.is_dir() and folder not in dirs:
            dirs.append(folder)
    return dirs


def _note(totals, stamp, name):
    try:
        stamp = int(stamp or 0)
    except (TypeError, ValueError):
        return
    title = str(name or "").strip()
    if stamp > totals["last"] and title:
        totals["last"] = stamp
        totals["lastName"] = title


def _steam(totals):
    seen = set()
    for root in _steam_roots():
        for apps in _library_dirs(root):
            for acf in apps.glob("appmanifest_*.acf"):
                text = acf.read_text(errors="replace")
                name = _quoted(text, "name")
                if not name or name.casefold() in SKIP or name.casefold().startswith("proton "):
                    continue
                appid = _quoted(text, "appid")
                if appid in seen:
                    continue
                seen.add(appid)
                totals["installed"] += 1
                try:
                    totals["bytes"] += int(_quoted(text, "SizeOnDisk") or "0")
                except ValueError:
                    pass
                _note(totals, _quoted(text, "LastPlayed"), name)
        names = {}
        for apps in _library_dirs(root):
            for acf in apps.glob("appmanifest_*.acf"):
                text = acf.read_text(errors="replace")
                appid = _quoted(text, "appid")
                title = _quoted(text, "name")
                if appid and title and title.casefold() not in SKIP and not title.casefold().startswith("proton "):
                    names[appid] = title
        for cfg in (root / "userdata").glob("*/config/localconfig.vdf"):
            text = cfg.read_text(errors="replace")
            for minutes in re.findall(r'"Playtime"\s+"(\d+)"', text):
                totals["minutes"] += int(minutes)
            # The install record lags games that were launched later.
            for appid, body in re.findall(r'"(\d+)"\s*\{([^{}]*)\}', text):
                played = _quoted(body, "LastPlayed")
                if played and appid in names:
                    _note(totals, played, names[appid])


def _lutris(totals):
    db = HOME / ".local/share/lutris/pga.db"
    if not db.is_file():
        return
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    except sqlite3.Error:
        return
    try:
        cols = {row[1] for row in con.execute("PRAGMA table_info(games)")}
        if "name" not in cols:
            return
        play = "playtime" if "playtime" in cols else "0"
        last = "lastplayed" if "lastplayed" in cols else "0"
        where = "WHERE installed = 1" if "installed" in cols else ""
        # Lutris stores playtime as hours.
        for name, hours, played in con.execute(f"SELECT name, {play}, {last} FROM games {where}"):
            if not name:
                continue
            totals["installed"] += 1
            totals["minutes"] += float(hours or 0) * 60
            _note(totals, played, name)
    except sqlite3.Error:
        return
    finally:
        con.close()


def _prefixes():
    found = []
    seen = set()
    candidates = [
        HOME / ".local/share/modern/battlenet/pfx",
        HOME / "Games/battlenet",
    ]
    for root in _steam_roots():
        base = root / "steamapps/compatdata"
        if base.is_dir():
            candidates.extend(base.glob("*/pfx"))
    for path in candidates:
        if not path.is_dir():
            continue
        resolved = path.resolve()
        if resolved not in seen:
            seen.add(resolved)
            found.append(resolved)
    return found


def _battlenet(totals):
    for prefix in _prefixes():
        configs = (prefix / "drive_c/users").glob("*/AppData/Roaming/Battle.net/Battle.net.config")
        for cfg in configs:
            try:
                data = json.loads(cfg.read_text(errors="replace"))
            except json.JSONDecodeError:
                continue
            games = data.get("Games") if isinstance(data, dict) else None
            if not isinstance(games, dict):
                continue
            for uid, row in games.items():
                if isinstance(row, dict) and uid in BATTLENET_NAMES:
                    _note(totals, row.get("LastPlayed"), BATTLENET_NAMES[uid])
        wow = prefix / "drive_c/Program Files (x86)/World of Warcraft"
        if not wow.is_dir():
            continue
        # A direct start updates the client log without the launcher stamp.
        for folder, title in WOW_LOGS.items():
            log = wow / folder / "Logs/Connection.log"
            if log.is_file():
                _note(totals, int(log.stat().st_mtime), title)


def _heroic(totals):
    base = HOME / ".config/heroic"
    for folder in (base / "store", base):
        path = folder / "playtime.json"
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(errors="replace"))
        except json.JSONDecodeError:
            continue
        rows = data.values() if isinstance(data, dict) else data
        if not isinstance(rows, list):
            rows = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            totals["minutes"] += int(row.get("playtime") or row.get("minutes") or 0)
    libs = list((base / "lib-cache").glob("*.json")) + list(base.glob("library.json"))
    for path in libs:
        try:
            data = json.loads(path.read_text(errors="replace"))
        except json.JSONDecodeError:
            continue
        games = data.get("games") if isinstance(data, dict) else data
        if not isinstance(games, list):
            continue
        for game in games:
            if not isinstance(game, dict):
                continue
            title = str(game.get("title") or game.get("name") or "")
            if not title or game.get("is_installed") is False:
                continue
            totals["installed"] += 1
            try:
                totals["bytes"] += int(game.get("install_size") or 0)
            except (TypeError, ValueError):
                pass


def main():
    totals = {"installed": 0, "minutes": 0, "bytes": 0, "last": 0, "lastName": ""}
    if HOME.is_dir():
        _steam(totals)
        _lutris(totals)
        _battlenet(totals)
        _heroic(totals)
    print(json.dumps({
        "hours": round(totals["minutes"] / 60, 1),
        "installed": totals["installed"],
        "bytes": totals["bytes"],
        "last": totals["last"],
        "lastName": totals["lastName"],
    }))


if __name__ == "__main__":
    main()
