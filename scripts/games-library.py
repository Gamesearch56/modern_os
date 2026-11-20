#!/usr/bin/env python3
"""Local game library totals. Steam, Lutris, and Heroic on this PC. No network."""
import json
import os
import re
import sqlite3
from pathlib import Path

HOME = Path(os.environ.get("HOME", "")).expanduser()
SKIP = {"steamworks common redistributables", "proton", "steam linux runtime"}


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
                try:
                    played = int(_quoted(text, "LastPlayed") or "0")
                except ValueError:
                    played = 0
                if played > totals["last"]:
                    totals["last"] = played
                    totals["lastName"] = name
        for cfg in (root / "userdata").glob("*/config/localconfig.vdf"):
            for minutes in re.findall(r'"Playtime"\s+"(\d+)"', cfg.read_text(errors="replace")):
                totals["minutes"] += int(minutes)


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
            try:
                stamp = int(played or 0)
            except (TypeError, ValueError):
                stamp = 0
            if stamp > totals["last"]:
                totals["last"] = stamp
                totals["lastName"] = str(name)
    except sqlite3.Error:
        return
    finally:
        con.close()


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
