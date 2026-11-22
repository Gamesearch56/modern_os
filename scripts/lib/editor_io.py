"""File access for the ModernOS Texteditor. One JSON object per call.

  load PATH [--max-bytes N]
  save PATH --encoding E --eol L [--stand-in] [--expect MTIME] [--no-clobber]
  trash PATH
  claim PATH PID | release PATH PID | owner PATH

save reads the text as UTF-8 on stdin. mtime is st_mtime_ns as a
string: QML numbers lose precision past 2^53. A save never follows a
stale view: --expect refuses when the file changed since it was read.
"""

import errno
import json
import os
import stat
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import editor_claim as claim  # noqa: E402
import editor_codec as codec  # noqa: E402
import safe_write  # noqa: E402

DEFAULT_MAX = 8 * 1024 * 1024
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
    def __init__(self, reason, **extra):
        super().__init__(reason)
        self.reason = reason
        self.extra = extra


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


def _os_fail(exc):
    return Fail(_ERRNO.get(exc.errno, "failed"))


def _option(args, name, default=None):
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            return args[i + 1]
        raise Fail("usage")
    return default


def cmd_load(args):
    path = _abs(args[0] if args else "")
    limit = int(_option(args, "--max-bytes", DEFAULT_MAX))
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
    except OSError as exc:
        raise _os_fail(exc) from None
    with os.fdopen(fd, "rb") as f:
        st = os.fstat(f.fileno())
        if stat.S_ISDIR(st.st_mode):
            raise Fail("directory")
        if not stat.S_ISREG(st.st_mode):
            raise Fail("special")
        if st.st_size > limit:
            raise Fail("tooLarge", size=st.st_size, limit=limit)
        data = f.read(limit + 1)
    if len(data) > limit:
        raise Fail("tooLarge", size=len(data), limit=limit)
    try:
        doc = codec.decode(data)
    except codec.Refuse as exc:
        raise Fail(exc.reason) from None
    doc.update({
        "ok": True,
        "path": path,
        "mtime": str(st.st_mtime_ns),
        "size": st.st_size,
        "writable": os.access(path, os.W_OK),
    })
    return doc


def cmd_save(args):
    path = _abs(args[0] if args else "")
    # Rewriting the installed checkout would change the running desktop.
    import files_safe as safe

    try:
        if safe.protected(path) or safe.protected(os.path.realpath(path)):
            raise Fail("protected")
    except safe.Refuse:
        raise Fail("badName") from None
    encoding = _option(args, "--encoding", "utf-8")
    eol = _option(args, "--eol", "lf")
    expect = _option(args, "--expect")
    try:
        text = sys.stdin.buffer.read().decode("utf-8")
    except UnicodeDecodeError:
        raise Fail("encoding") from None
    try:
        data = codec.encode(text, encoding, eol, "--stand-in" in args)
    except codec.Refuse as exc:
        raise Fail(exc.reason) from None
    target = os.path.realpath(path)
    try:
        raw = os.stat(target)
    except FileNotFoundError:
        raw = None
    except OSError as exc:
        raise _os_fail(exc) from None
    if raw is not None:
        if stat.S_ISDIR(raw.st_mode):
            raise Fail("directory")
        if not stat.S_ISREG(raw.st_mode):
            raise Fail("special")
        if "--no-clobber" in args:
            raise Fail("exists")
        if expect is not None and expect != str(raw.st_mtime_ns):
            raise Fail("changed")
        # A rename would replace a read-only file the folder lets us drop.
        if not os.access(target, os.W_OK):
            raise Fail("denied")
    try:
        safe_write.write(target, data, raw)
        done = os.stat(target)
    except OSError as exc:
        raise _os_fail(exc) from None
    return {"ok": True, "path": path, "mtime": str(done.st_mtime_ns), "size": done.st_size}


def cmd_trash(args):
    import files_safe as safe
    import files_trash as trash

    path = _abs(args[0] if args else "")
    try:
        trash.trash_one(path)
    except safe.Refuse as exc:
        raise Fail(exc.reason) from None
    except OSError as exc:
        raise _os_fail(exc) from None
    return {"ok": True, "path": path}


def main(argv):
    commands = {
        "load": cmd_load,
        "save": cmd_save,
        "trash": cmd_trash,
        "claim": lambda a: claim.claim(_abs(a[0] if a else ""), int(a[1]) if len(a) > 1 else 0),
        "release": lambda a: claim.release(_abs(a[0] if a else ""), int(a[1]) if len(a) > 1 else 0),
        "owner": lambda a: claim.owner(_abs(a[0] if a else "")),
    }
    if len(argv) < 3 or argv[1] not in commands:
        emit({"ok": False, "error": "usage"})
        return 2
    try:
        out = commands[argv[1]](argv[2:])
    except Fail as exc:
        out = {"ok": False, "error": exc.reason}
        out.update(exc.extra)
    except (ValueError, IndexError):
        out = {"ok": False, "error": "usage"}
    except OSError as exc:
        out = {"ok": False, "error": _ERRNO.get(exc.errno, "failed")}
    emit(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
