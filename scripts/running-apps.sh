#!/usr/bin/env bash
# Desktop apps whose main process is running but may have no window
# (Electron close-to-tray without StatusNotifier, e.g. Discord on Wayland).
set -euo pipefail

python3 - <<'PY'
import json
import os
from pathlib import Path

def data_dirs():
    home = os.environ.get("HOME", "")
    xdg = os.environ.get("XDG_DATA_HOME") or (home + "/.local/share")
    dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    out = [xdg]
    for p in dirs.split(":"):
        p = p.strip()
        if p:
            out.append(p)
    return out

def parse_desktop(path):
    data = {}
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    in_entry = False
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_entry = line == "[Desktop Entry]"
            continue
        if not in_entry or "=" not in line:
            continue
        k, _, v = line.partition("=")
        data[k.strip()] = v.strip()
    if data.get("Type", "Application") != "Application":
        return None
    if data.get("NoDisplay", "").lower() == "true":
        return None
    if data.get("Hidden", "").lower() == "true":
        return None
    exec_line = data.get("Exec", "")
    if not exec_line:
        return None
    token = exec_line.split()[0]
    if token.startswith('"') and token.endswith('"'):
        token = token[1:-1]
    base = os.path.basename(token).lower()
    wm = (data.get("StartupWMClass") or "").lower()
    stem = Path(path).stem.lower()
    name = data.get("Name") or stem
    icon = data.get("Icon") or stem
    needles = {n for n in (base, wm, stem) if n and len(n) >= 3}
    if not needles:
        return None
    return {
        "id": Path(path).name,
        "name": name,
        "icon": icon,
        "class": wm or base or stem,
        "needles": needles,
    }

def load_desktops():
    by_stem = {}
    for d in data_dirs():
        appdir = Path(d) / "applications"
        if not appdir.is_dir():
            continue
        try:
            names = os.listdir(appdir)
        except OSError:
            continue
        for fn in names:
            if not fn.endswith(".desktop"):
                continue
            parsed = parse_desktop(appdir / fn)
            if not parsed:
                continue
            stem = Path(fn).stem.lower()
            if stem not in by_stem:
                by_stem[stem] = parsed
    return list(by_stem.values())

def running_procs():
    uid = os.getuid()
    found = []
    try:
        pids = os.listdir("/proc")
    except OSError:
        return found
    for pid in pids:
        if not pid.isdigit():
            continue
        base = Path("/proc") / pid
        try:
            status = (base / "status").read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        uid_ok = False
        for line in status.splitlines():
            if line.startswith("Uid:"):
                parts = line.split()
                uid_ok = len(parts) > 1 and parts[1] == str(uid)
                break
        if not uid_ok:
            continue
        try:
            raw = (base / "cmdline").read_bytes()
        except OSError:
            continue
        if not raw or b"--type=" in raw:
            continue
        parts = [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p]
        if not parts:
            continue
        argv0 = os.path.basename(parts[0]).lower()
        if argv0 in ("exe",):
            continue
        try:
            comm = (base / "comm").read_text(encoding="utf-8", errors="replace").strip().lower()
        except OSError:
            comm = ""
        try:
            exe = os.path.basename(os.readlink(base / "exe")).lower()
        except OSError:
            exe = ""
        names = {n for n in (argv0, comm, exe) if n and len(n) >= 3}
        if names:
            found.append({"pid": int(pid), "names": names})
    return found

desktops = load_desktops()
procs = running_procs()
running = set()
for p in procs:
    running |= p["names"]
out = []
seen = set()
for d in desktops:
    if not (d["needles"] & running):
        continue
    stem = Path(d["id"]).stem.lower()
    if stem in seen:
        continue
    seen.add(stem)
    pids = [p["pid"] for p in procs if d["needles"] & p["names"]]
    out.append({
        "id": d["id"],
        "name": d["name"],
        "icon": d["icon"],
        "class": d["class"],
        "pids": pids,
    })
out.sort(key=lambda x: x["name"].lower())
print(json.dumps(out, ensure_ascii=False))
PY
