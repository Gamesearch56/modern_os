"""File access for the ModernOS Imageviewer. One JSON object per call.

  list PATH...                  the images to step through (see _list)
  info PATH                     size, mtime, type, writable
  trash PATH                    move to the trash
  rotate PATH DEGREES --expect MTIME   save a 90/180/270 turn into the file
  copy PATH | copy-path PATH    image or path to the clipboard

mtime is st_mtime_ns as a string: QML numbers lose precision past 2^53.
"""

import errno
import json
import os
import re
import shutil
import stat
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import safe_write  # noqa: E402
import viewer_formats as formats  # noqa: E402

MAX_ITEMS = 20000
MAX_ROTATE = 256 * 1024 * 1024
MAX_COPY = 64 * 1024 * 1024
_ERRNO = {
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


def _abs(path):
    if not path or "\x00" in path:
        raise Fail("badName")
    if path.startswith("file://"):
        path = path[7:]
    if not os.path.isabs(path):
        raise Fail("badName")
    return os.path.normpath(path)


def _natural(name):
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", name.casefold())]


def _images_in(folder, keep=None):
    found = []
    with os.scandir(folder) as it:
        for entry in it:
            hidden = entry.name.startswith(".")
            if entry.path == keep or (not hidden and formats.supported(entry.name)):
                try:
                    if entry.is_file():
                        found.append(entry.path)
                except OSError:
                    continue
    found.sort(key=lambda p: _natural(os.path.basename(p)))
    return found[:MAX_ITEMS]


def _list(args):
    """One file: every image in its folder, starting at that file, like
    stepping through a camera roll. One folder: its images. Several
    paths: those files, folders expanded, in the order given."""
    paths = [_abs(a) for a in args if a]
    if not paths:
        raise Fail("usage")
    if len(paths) == 1:
        p = paths[0]
        try:
            st = os.stat(p)
        except OSError as exc:
            raise Fail(_ERRNO.get(exc.errno, "failed")) from None
        if stat.S_ISDIR(st.st_mode):
            items, index = _images_in(p), 0
        elif not stat.S_ISREG(st.st_mode):
            raise Fail("special")
        else:
            items = _images_in(os.path.dirname(p), keep=p)
            index = items.index(p) if p in items else 0
            if p not in items:
                items.insert(0, p)
    else:
        items, index = [], 0
        for p in paths:
            if os.path.isdir(p):
                items.extend(_images_in(p))
            elif os.path.isfile(p):
                items.append(p)
        items = items[:MAX_ITEMS]
    if not items:
        raise Fail("empty")
    return {"ok": True, "items": items, "index": index}


def _stat_file(path):
    try:
        st = os.stat(path)
    except OSError as exc:
        raise Fail(_ERRNO.get(exc.errno, "failed")) from None
    if stat.S_ISDIR(st.st_mode):
        raise Fail("directory")
    if not stat.S_ISREG(st.st_mode):
        raise Fail("special")
    return st


def cmd_info(args):
    path = _abs(args[0] if args else "")
    st = _stat_file(path)
    return {
        "ok": True,
        "path": path,
        "size": st.st_size,
        "mtime": str(st.st_mtime_ns),
        "mime": formats.mime(path),
        "animated": formats.ext(path) in formats.ANIMATED,
        "rotatable": formats.magick_format(path) is not None,
        "writable": os.access(path, os.W_OK),
    }


def cmd_trash(args):
    import files_safe as safe
    import files_trash as trash

    path = _abs(args[0] if args else "")
    try:
        trash.trash_one(path)
    except safe.Refuse as exc:
        raise Fail(exc.reason) from None
    except OSError as exc:
        raise Fail(_ERRNO.get(exc.errno, "failed")) from None
    return {"ok": True, "path": path}


def cmd_rotate(args):
    path = _abs(args[0] if args else "")
    degrees = int(args[1]) if len(args) > 1 else 0
    expect = args[args.index("--expect") + 1] if "--expect" in args[:-1] else None
    if degrees not in (90, 180, 270):
        raise Fail("usage")
    fmt = formats.magick_format(path)
    tool = shutil.which("magick")
    if not fmt or not tool:
        raise Fail("unsupported")
    target = os.path.realpath(path)
    raw = _stat_file(target)
    if expect is not None and expect != str(raw.st_mtime_ns):
        raise Fail("changed")
    if not os.access(target, os.W_OK):
        raise Fail("denied")
    if raw.st_size > MAX_ROTATE:
        raise Fail("tooLarge")
    with open(target, "rb") as f:
        data = f.read(MAX_ROTATE + 1)
    # Bytes in and out on pipes: ImageMagick never parses the file name,
    # so "[0]", "~", or "png:" in a name cannot change what it reads.
    run = subprocess.run([tool, fmt + ":-", "-auto-orient", "-rotate", str(degrees), fmt + ":-"],
                         input=data, capture_output=True, timeout=120)
    if run.returncode != 0 or not run.stdout:
        raise Fail("failed")
    try:
        safe_write.write(target, run.stdout, raw)
        done = os.stat(target)
    except OSError as exc:
        raise Fail(_ERRNO.get(exc.errno, "failed")) from None
    return {"ok": True, "path": path, "mtime": str(done.st_mtime_ns), "size": done.st_size}


def _wl_copy(data, mime):
    tool = shutil.which("wl-copy")
    if not tool:
        raise Fail("unsupported")
    subprocess.run([tool, "--type", mime], input=data, check=True, timeout=10,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cmd_copy(args):
    path = _abs(args[0] if args else "")
    st = _stat_file(path)
    if st.st_size > MAX_COPY:
        raise Fail("tooLarge")
    with open(path, "rb") as f:
        _wl_copy(f.read(MAX_COPY + 1), formats.mime(path) or "application/octet-stream")
    return {"ok": True}


def cmd_copy_path(args):
    path = _abs(args[0] if args else "")
    _wl_copy(path.encode("utf-8", "surrogateescape"), "text/plain;charset=utf-8")
    return {"ok": True}


def main(argv):
    commands = {
        "list": _list,
        "info": cmd_info,
        "trash": cmd_trash,
        "rotate": cmd_rotate,
        "copy": cmd_copy,
        "copy-path": cmd_copy_path,
    }
    if len(argv) < 3 or argv[1] not in commands:
        emit({"ok": False, "error": "usage"})
        return 2
    try:
        out = commands[argv[1]](argv[2:])
    except Fail as exc:
        out = {"ok": False, "error": exc.reason}
    except (ValueError, IndexError):
        out = {"ok": False, "error": "usage"}
    except subprocess.TimeoutExpired:
        out = {"ok": False, "error": "failed"}
    except subprocess.CalledProcessError:
        out = {"ok": False, "error": "failed"}
    except OSError as exc:
        out = {"ok": False, "error": _ERRNO.get(exc.errno, "failed")}
    emit(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
