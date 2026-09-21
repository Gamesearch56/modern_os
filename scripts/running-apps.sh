#!/usr/bin/env bash
# Desktop apps whose *main* process is running but may have no window
# (Electron close-to-tray without StatusNotifier). Emits one entry per
# .desktop with root PIDs only — helpers/children are not listed.
set -euo pipefail

python3 - <<'PY'
import json
import os
import shlex
from pathlib import Path

# Exec wrappers / runtimes that must never be matching needles.
GENERIC = {
    "appimage", "bash", "dbus-run-session", "dotnet", "electron", "env",
    "firejail", "flatpak", "gamemoderun", "java", "mono", "node", "perl",
    "python", "python3", "ruby", "sh", "snap", "systemd-run", "wine",
    "wine64", "wineserver",
}

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

def unwrap_exec(exec_line: str) -> str:
    """Binary basename after env/flatpak/gamemoderun wrappers."""
    try:
        parts = shlex.split(exec_line, posix=True)
    except ValueError:
        parts = exec_line.split()
    i = 0
    while i < len(parts):
        tok = parts[i].strip().strip('"')
        base = os.path.basename(tok).lower()
        if base == "env":
            i += 1
            while i < len(parts) and "=" in parts[i] and not parts[i].startswith("-"):
                i += 1
            continue
        if base == "flatpak":
            i += 1
            while i < len(parts):
                p = parts[i]
                if p == "run":
                    i += 1
                    while i < len(parts) and parts[i].startswith("--"):
                        if "=" not in parts[i] and i + 1 < len(parts):
                            i += 2
                        else:
                            i += 1
                    if i < len(parts):
                        return os.path.basename(parts[i]).lower()
                    return ""
                i += 1
            return ""
        if base in ("gamemoderun", "firejail", "dbus-run-session", "systemd-run"):
            i += 1
            continue
        if base.startswith("-"):
            i += 1
            continue
        return base
    return ""

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
    binary = unwrap_exec(exec_line)
    wm = (data.get("StartupWMClass") or "").lower()
    stem = Path(path).stem.lower()
    name = data.get("Name") or stem
    icon = data.get("Icon") or stem
    needles = set()
    for n in (binary, wm, stem):
        if not n or len(n) < 3 or n in GENERIC:
            continue
        needles.add(n)
    if not needles:
        return None
    return {
        "id": Path(path).name,
        "name": name,
        "icon": icon,
        "class": wm or binary or stem,
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

def status_fields(pid: int):
    try:
        text = Path(f"/proc/{pid}/status").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    out = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        out[k.strip()] = v.strip()
    return out

def running_procs():
    uid = os.getuid()
    found = []
    try:
        pids = os.listdir("/proc")
    except OSError:
        return found
    for name in pids:
        if not name.isdigit():
            continue
        pid = int(name)
        st = status_fields(pid)
        if not st:
            continue
        parts = st.get("Uid", "").split()
        if not parts or parts[0] != str(uid):
            continue
        try:
            ppid = int(st.get("PPid", "0").split()[0])
        except ValueError:
            ppid = 0
        base = Path("/proc") / name
        try:
            raw = (base / "cmdline").read_bytes()
        except OSError:
            continue
        if not raw or b"--type=" in raw:
            continue
        argv = [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p]
        if not argv:
            continue
        argv0 = os.path.basename(argv[0]).lower()
        if argv0 in ("exe",) or argv0 in GENERIC:
            continue
        try:
            comm = (base / "comm").read_text(encoding="utf-8", errors="replace").strip().lower()
        except OSError:
            comm = ""
        try:
            exe = os.path.basename(os.readlink(base / "exe")).lower()
        except OSError:
            exe = ""
        names = {n for n in (argv0, comm, exe) if n and len(n) >= 3 and n not in GENERIC}
        if names:
            found.append({"pid": pid, "ppid": ppid, "names": names})
    return found

def root_pids(matched):
    """Keep only process-tree roots among matches (Windows-style main apps)."""
    ids = {p["pid"] for p in matched}
    return [p["pid"] for p in matched if p["ppid"] not in ids]

desktops = load_desktops()
procs = running_procs()
out = []
seen = set()
for d in desktops:
    matched = [p for p in procs if d["needles"] & p["names"]]
    if not matched:
        continue
    stem = Path(d["id"]).stem.lower()
    if stem in seen:
        continue
    seen.add(stem)
    pids = root_pids(matched)
    if not pids:
        continue
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
