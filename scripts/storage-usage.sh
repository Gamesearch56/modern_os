#!/usr/bin/env bash
# Unprivileged category sizes for Settings → Storage. Prints one JSON
# object. Fixture env is only for tests (a fake HOME plus optional root).
set -euo pipefail

export LC_ALL=C

HOME_DIR="${HOME:-}"
ROOT_DIR=""
if [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ -n "${MODERN_USAGE_HOME:-}" ]; then
    HOME_DIR="${MODERN_USAGE_HOME}"
    ROOT_DIR="${MODERN_USAGE_ROOT:-}"
fi
[ -n "$HOME_DIR" ] || HOME_DIR="/"

xdg_dir() {
    local key="$1" fallback="$2" got=""
    if command -v xdg-user-dir >/dev/null 2>&1 && [ -z "${ROOT_DIR}" ]; then
        got="$(xdg-user-dir "$key" 2>/dev/null || true)"
    fi
    if [ -n "$got" ] && [ "$got" != "$HOME_DIR" ]; then
        printf '%s\n' "$got"
        return
    fi
    printf '%s\n' "$HOME_DIR/$fallback"
}

export MODERN_USAGE_HOME_DIR="$HOME_DIR"
export MODERN_USAGE_ROOT_DIR="$ROOT_DIR"
MODERN_USAGE_DOCUMENTS="$(xdg_dir DOCUMENTS Documents)"
MODERN_USAGE_DOWNLOAD="$(xdg_dir DOWNLOAD Downloads)"
MODERN_USAGE_PICTURES="$(xdg_dir PICTURES Pictures)"
MODERN_USAGE_VIDEOS="$(xdg_dir VIDEOS Videos)"
MODERN_USAGE_MUSIC="$(xdg_dir MUSIC Music)"
MODERN_USAGE_DESKTOP="$(xdg_dir DESKTOP Desktop)"
export MODERN_USAGE_DOCUMENTS MODERN_USAGE_DOWNLOAD MODERN_USAGE_PICTURES \
    MODERN_USAGE_VIDEOS MODERN_USAGE_MUSIC MODERN_USAGE_DESKTOP

python3 - <<'PY'
import json
import os
import re
import subprocess
import sys

HOME = os.environ["MODERN_USAGE_HOME_DIR"]
ROOT = os.environ.get("MODERN_USAGE_ROOT_DIR") or ""


def under(root, *parts):
    return os.path.join(root, *parts)


def unique_dirs(paths):
    out = []
    seen = set()
    for raw in paths:
        if not raw:
            continue
        try:
            path = os.path.realpath(raw)
        except OSError:
            continue
        if not os.path.isdir(path) or path in seen:
            continue
        seen.add(path)
        out.append(path)
    return out


def fstype(path):
    if not path or not os.path.isdir(path):
        return ""
    try:
        proc = subprocess.run(
            ["stat", "-f", "-c", "%T", path],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if proc.returncode != 0:
        return ""
    return (proc.stdout or "").strip()


def btrfs_exclusive(path):
    # du -sb counts every file in the snapshot at its full size, including
    # extents the live system still owns. On btrfs that reports a second
    # copy of the disk. Exclusive is the space that goes away with the
    # snapshots.
    if fstype(path) != "btrfs":
        return None
    try:
        proc = subprocess.run(
            ["btrfs", "filesystem", "du", "-s", "--raw", "--", path],
            check=False,
            capture_output=True,
            text=True,
            timeout=45,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 0
    exclusive = None
    for line in (proc.stdout or "").splitlines():
        parts = line.split()
        if len(parts) < 4 or parts[0] == "Total":
            continue
        try:
            exclusive = int(parts[1])
        except ValueError:
            continue
    if exclusive is None:
        return 0
    return exclusive


def du(paths):
    dirs = unique_dirs(paths)
    if not dirs:
        return 0
    try:
        proc = subprocess.run(
            ["du", "-sb", "--"] + dirs,
            check=False,
            capture_output=True,
            text=True,
            timeout=45,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 0
    total = 0
    for line in (proc.stdout or "").splitlines():
        num = line.split(None, 1)
        if not num:
            continue
        try:
            total += int(num[0])
        except ValueError:
            continue
    return total


def pacman_apps():
    try:
        proc = subprocess.run(
            ["pacman", "-Qi"],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
            env={**os.environ, "LC_ALL": "C"},
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    units = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4}
    total = 0
    found = False
    for line in proc.stdout.splitlines():
        if not line.startswith("Installed Size"):
            continue
        m = re.search(r"([0-9]+(?:\.[0-9]+)?)\s+(B|KiB|MiB|GiB|TiB)", line)
        if not m:
            continue
        found = True
        total += int(float(m.group(1)) * units[m.group(2)])
    return total if found else None


usr = under(ROOT, "usr") if ROOT else "/usr"
var_cache = under(ROOT, "var", "cache") if ROOT else "/var/cache"
snapshots = under(ROOT, "snapshots") if ROOT else "/.snapshots"
flatpak = under(ROOT, "var", "lib", "flatpak") if ROOT else "/var/lib/flatpak"

games = du([
    under(HOME, ".local", "share", "Steam"),
    under(HOME, ".steam", "steam"),
    under(HOME, ".var", "app", "com.valvesoftware.Steam"),
    under(HOME, ".local", "share", "lutris"),
    under(HOME, "Games"),
    under(HOME, ".local", "share", "bottles"),
    under(HOME, ".config", "heroic"),
    under(HOME, ".local", "share", "heroic"),
    under(HOME, ".wine"),
])
files = du([
    os.environ.get("MODERN_USAGE_DOCUMENTS", ""),
    os.environ.get("MODERN_USAGE_DOWNLOAD", ""),
    os.environ.get("MODERN_USAGE_PICTURES", ""),
    os.environ.get("MODERN_USAGE_VIDEOS", ""),
    os.environ.get("MODERN_USAGE_MUSIC", ""),
    os.environ.get("MODERN_USAGE_DESKTOP", ""),
])
if ROOT:
    apps = du([usr, flatpak, under(HOME, ".local", "share", "flatpak")])
else:
    apps = pacman_apps()
    if apps is None:
        apps = du([usr, flatpak, under(HOME, ".local", "share", "flatpak")])
cache = du([under(HOME, ".cache"), var_cache])
backups = btrfs_exclusive(snapshots)
if backups is None:
    backups = du([snapshots])

json.dump({
    "games": games,
    "files": files,
    "apps": int(apps),
    "cache": cache,
    "backups": backups,
}, sys.stdout, separators=(",", ":"))
print()
PY
