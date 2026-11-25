"""Which Texteditor window has a file open, so a second open focuses it.

One file per open document under $XDG_RUNTIME_DIR/modern-editor, named
by a hash of the real path and holding the window's process id. A claim
only counts while that process is still an editor window, so a crash
never locks a file.
"""

import hashlib
import os

MARK = "editor.qml"


def _dir():
    base = os.environ.get("MODERN_EDITOR_RUNTIME") or os.path.join(
        os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "modern-editor")
    os.makedirs(base, mode=0o700, exist_ok=True)
    return base


def _slot(path):
    real = os.path.realpath(path)
    return os.path.join(_dir(), hashlib.sha256(real.encode("utf-8", "surrogateescape")).hexdigest()[:32])


def _alive(pid):
    if pid <= 0:
        return False
    try:
        with open("/proc/%d/cmdline" % pid, "rb") as f:
            cmdline = f.read().decode("utf-8", "replace")
    except OSError:
        return False
    return MARK in cmdline or os.environ.get("MODERN_EDITOR_ANY_PID") == "1"


def _holder(slot):
    try:
        with open(slot, encoding="utf-8") as f:
            return int((f.readline() or "0").strip() or 0)
    except (OSError, ValueError):
        return 0


def owner(path):
    pid = _holder(_slot(path))
    return {"ok": True, "pid": pid if _alive(pid) else 0}


def claim(path, pid):
    if pid <= 0:
        return {"ok": False, "error": "usage"}
    slot = _slot(path)
    for _ in range(2):
        try:
            fd = os.open(slot, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC, 0o600)
        except FileExistsError:
            held = _holder(slot)
            if held == pid:
                return {"ok": True, "pid": pid}
            if _alive(held):
                return {"ok": False, "error": "open", "pid": held}
            try:
                os.unlink(slot)
            except FileNotFoundError:
                pass
            continue
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write("%d\n%s\n" % (pid, os.path.realpath(path)))
        return {"ok": True, "pid": pid}
    return {"ok": False, "error": "busy"}


def release(path, pid):
    slot = _slot(path)
    if _holder(slot) == pid:
        try:
            os.unlink(slot)
        except FileNotFoundError:
            pass
    return {"ok": True}
