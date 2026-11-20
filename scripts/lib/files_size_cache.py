"""Saved folder totals.

A directory's total is reused while its own stamp is unchanged. Storage
cleanup deletes this directory, and the next visit measures again.
"""

import hashlib
import json
import os
import stat
import tempfile


def root():
    override = os.environ.get("MODERN_SIZE_CACHE") or ""
    if override:
        base = override
    else:
        home = os.environ.get("XDG_CACHE_HOME") or ""
        if not home:
            home = os.path.join(os.environ.get("HOME") or "", ".cache")
        base = os.path.join(home, "modern", "folder-sizes")
    if not base or base == "/" or os.path.islink(base):
        return ""
    parent = os.path.dirname(base)
    if os.path.islink(parent):
        return ""
    return base


def _file(path):
    base = root()
    if not base:
        return ""
    digest = hashlib.sha256(os.fsencode(path)).hexdigest()
    return os.path.join(base, digest[:2], digest + ".json")


def read(path, mtime_ns):
    dest = _file(path)
    if not dest:
        return None
    try:
        with open(dest, "r", encoding="utf-8") as handle:
            row = json.load(handle)
    except (OSError, ValueError, TypeError):
        return None
    if not isinstance(row, dict) or row.get("mtime_ns") != mtime_ns:
        return None
    size = row.get("size")
    if isinstance(size, bool) or not isinstance(size, int) or size < 0:
        return None
    return size


def write(path, mtime_ns, size):
    dest = _file(path)
    if not dest:
        return
    folder = os.path.dirname(dest)
    try:
        os.makedirs(folder, exist_ok=True)
        handle = tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=folder, delete=False, prefix=".tmp-"
        )
        with handle:
            json.dump({"mtime_ns": int(mtime_ns), "size": int(size)}, handle)
            handle.write("\n")
        os.replace(handle.name, dest)
    except OSError:
        return


def forget(path):
    current = str(path or "")
    while current:
        dest = _file(current)
        if dest:
            try:
                os.remove(dest)
            except OSError:
                pass
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent


def total(path, st):
    saved = read(path, st.st_mtime_ns)
    if saved is not None:
        return saved
    amount = 0
    try:
        with os.scandir(path) as scan:
            for item in scan:
                try:
                    child = item.stat(follow_symlinks=False)
                except OSError:
                    continue
                if stat.S_ISLNK(child.st_mode):
                    continue
                if stat.S_ISDIR(child.st_mode):
                    amount += total(item.path, child)
                else:
                    amount += child.st_size
    except OSError:
        return amount
    write(path, st.st_mtime_ns, amount)
    return amount
