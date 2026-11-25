#!/usr/bin/env bash
# SIGKILL a user app and its descendants. Taskbar End-task equivalent.
# Usage: kill-app.sh [--pid N]... [--name token]...
set -euo pipefail

python3 - -- "$@" <<'PY'
import os
import signal
import sys
from pathlib import Path

PROTECTED = {
    "dbus-broker", "dbus-daemon", "hypridle", "hyprland", "hyprlock",
    "pipewire", "pipewire-pulse", "qs", "quickshell", "systemd",
    "wireplumber", "xdg-desktop-portal", "xdg-desktop-portal-gtk",
    "xdg-desktop-portal-hyprland",
}

# Never match by these short/shared names — kill by PID tree instead.
GENERIC_NAMES = {
    "appimage", "bash", "electron", "env", "flatpak", "gamemoderun",
    "java", "node", "python", "python3", "sh", "steamwebhelper", "wine",
    "wine64", "wineserver",
}

def parse_args(argv):
    pids, names = [], []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--pid" and i + 1 < len(argv):
            try:
                pids.append(int(argv[i + 1]))
            except ValueError:
                pass
            i += 2
            continue
        if a == "--name" and i + 1 < len(argv):
            n = argv[i + 1].strip().lower()
            if n:
                names.append(n)
            i += 2
            continue
        i += 1
    return pids, names

def status_map(pid):
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

def owned(pid, uid):
    st = status_map(pid)
    if not st:
        return False
    parts = st.get("Uid", "").split()
    return len(parts) > 0 and parts[0] == str(uid)

def names_of(pid):
    found = set()
    base = Path(f"/proc/{pid}")
    try:
        comm = (base / "comm").read_text(encoding="utf-8", errors="replace").strip().lower()
        if comm:
            found.add(comm)
    except OSError:
        pass
    try:
        exe = os.path.basename(os.readlink(base / "exe")).lower()
        if exe:
            found.add(exe)
    except OSError:
        pass
    try:
        raw = (base / "cmdline").read_bytes()
        parts = [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p]
        if parts:
            found.add(os.path.basename(parts[0]).lower())
    except OSError:
        pass
    return {n for n in found if n}

def ppid_of(pid):
    st = status_map(pid)
    if not st:
        return 0
    try:
        return int(st.get("PPid", "0").split()[0])
    except ValueError:
        return 0

def all_user_pids(uid):
    out = []
    try:
        ents = os.listdir("/proc")
    except OSError:
        return out
    for name in ents:
        if not name.isdigit():
            continue
        pid = int(name)
        if owned(pid, uid):
            out.append(pid)
    return out

def matches(proc_names, needle):
    n = needle.replace(".desktop", "").strip().lower()
    if len(n) < 3 or n in GENERIC_NAMES or n in PROTECTED:
        return False
    extras = (n + "-launcher", n + "-bin", n + ".bin")
    for p in proc_names:
        if p in PROTECTED or p in GENERIC_NAMES:
            continue
        if p == n or p in extras:
            return True
        if n == p + "-launcher" or n == p + "-bin":
            return True
    return False
def descendants(roots, by_parent):
    seen = set()
    stack = list(roots)
    while stack:
        pid = stack.pop()
        if pid in seen:
            continue
        seen.add(pid)
        for c in by_parent.get(pid, []):
            stack.append(c)
    return seen

uid = os.getuid()
want_pids, want_names = parse_args(sys.argv[1:])
if not want_pids and not want_names:
    sys.exit(0)

user_pids = all_user_pids(uid)
by_parent = {}
for pid in user_pids:
    parent = ppid_of(pid)
    by_parent.setdefault(parent, []).append(pid)

chosen = set()
for pid in want_pids:
    if pid > 1 and owned(pid, uid) and not (names_of(pid) & PROTECTED):
        chosen.add(pid)

for pid in user_pids:
    nms = names_of(pid)
    if nms & PROTECTED:
        continue
    for needle in want_names:
        if matches(nms, needle):
            chosen.add(pid)
            break

targets = descendants(chosen, by_parent)
for pid in sorted(targets, reverse=True):
    if pid <= 1 or not owned(pid, uid):
        continue
    if names_of(pid) & PROTECTED:
        continue
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass
PY
