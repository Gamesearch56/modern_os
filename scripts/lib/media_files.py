"""Shared file plumbing for the ModernOS Imageviewer and Mediaplayer helpers:
one JSON object per call, refusal reasons instead of tracebacks, and the
"one file opens its folder" listing both apps use."""

import errno
import json
import os
import re
import shutil
import stat
import subprocess
import sys

MAX_ITEMS = 20000
ERRNO = {
    errno.EACCES: "denied",
    errno.EPERM: "denied",
    errno.EROFS: "readOnlyFs",
    errno.ENOSPC: "full",
    errno.EDQUOT: "full",
    errno.ENOENT: "missing",
    errno.EISDIR: "directory",
    errno.ENAMETOOLONG: "badName",
}


class Fail(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.write("\n")


def abs_path(path):
    if not path or "\x00" in path:
        raise Fail("badName")
    if path.startswith("file://"):
        path = path[7:]
    if not os.path.isabs(path):
        raise Fail("badName")
    return os.path.normpath(path)


def natural(name):
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", name.casefold())]


def stat_file(path):
    try:
        st = os.stat(path)
    except OSError as exc:
        raise Fail(ERRNO.get(exc.errno, "failed")) from None
    if stat.S_ISDIR(st.st_mode):
        raise Fail("directory")
    if not stat.S_ISREG(st.st_mode):
        raise Fail("special")
    return st


def files_in(folder, accept, keep=None):
    """Regular files in `folder` that `accept(name)` likes, hidden ones
    skipped unless it is `keep`, in natural order."""
    found = []
    with os.scandir(folder) as it:
        for entry in it:
            hidden = entry.name.startswith(".")
            if entry.path == keep or (not hidden and accept(entry.name)):
                try:
                    if entry.is_file():
                        found.append(entry.path)
                except OSError:
                    continue
    found.sort(key=_order)
    return found[:MAX_ITEMS]


def _order(path):
    # "clip.mp4" before "clip2.mp4": the name first, the extension after.
    stem, extension = os.path.splitext(os.path.basename(path))
    return natural(stem), extension.casefold()


def list_paths(args, accept, siblings=None):
    """One file: the files in its folder that `siblings(path)` (default
    `accept`) likes, starting at that file; the file itself is kept even
    when nothing else likes it. One folder: what `accept` likes in it.
    Several paths: those files, folders expanded, in the order given."""
    paths = [abs_path(a) for a in args if a]
    if not paths:
        raise Fail("usage")
    if len(paths) == 1:
        p = paths[0]
        try:
            st = os.stat(p)
        except OSError as exc:
            raise Fail(ERRNO.get(exc.errno, "failed")) from None
        if stat.S_ISDIR(st.st_mode):
            items, index = files_in(p, accept), 0
        elif not stat.S_ISREG(st.st_mode):
            raise Fail("special")
        else:
            items = files_in(os.path.dirname(p), siblings(p) if siblings else accept, keep=p)
            if p not in items:
                items.insert(0, p)
            index = items.index(p)
    else:
        items, index = [], 0
        for p in paths:
            if os.path.isdir(p):
                items.extend(files_in(p, accept))
            elif os.path.isfile(p):
                items.append(p)
        items = items[:MAX_ITEMS]
    if not items:
        raise Fail("empty")
    return {"ok": True, "items": items, "index": index}


def wl_copy(data, mime):
    tool = shutil.which("wl-copy")
    if not tool:
        raise Fail("unsupported")
    subprocess.run([tool, "--type", mime], input=data, check=True, timeout=10,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cmd_copy_path(args):
    path = abs_path(args[0] if args else "")
    wl_copy(path.encode("utf-8", "surrogateescape"), "text/plain;charset=utf-8")
    return {"ok": True}


def run(commands, argv):
    """Dispatch argv[1] to `commands`; usage errors exit 2, refusals 0."""
    if len(argv) < 3 or argv[1] not in commands:
        emit({"ok": False, "error": "usage"})
        return 2
    try:
        out = commands[argv[1]](argv[2:])
    except Fail as exc:
        out = {"ok": False, "error": exc.reason}
    except (ValueError, IndexError):
        out = {"ok": False, "error": "usage"}
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
        out = {"ok": False, "error": "failed"}
    except OSError as exc:
        out = {"ok": False, "error": ERRNO.get(exc.errno, "failed")}
    emit(out)
    return 0
