"""File access for the ModernOS Imageviewer. One JSON object per call.

  list PATH...                  the images to step through (media_files.list_paths)
  info PATH                     size, mtime, type, writable
  trash PATH                    move to the trash
  rotate PATH DEGREES --expect MTIME   save a 90/180/270 turn into the file
  copy PATH | copy-path PATH    image or path to the clipboard

mtime is st_mtime_ns as a string: QML numbers lose precision past 2^53.
"""

import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import media_files as mf  # noqa: E402
import safe_write  # noqa: E402
import viewer_formats as formats  # noqa: E402

MAX_ROTATE = 256 * 1024 * 1024
MAX_COPY = 64 * 1024 * 1024
Fail = mf.Fail


def cmd_list(args):
    return mf.list_paths(args, formats.supported)


def cmd_info(args):
    path = mf.abs_path(args[0] if args else "")
    st = mf.stat_file(path)
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

    path = mf.abs_path(args[0] if args else "")
    try:
        trash.trash_one(path)
    except safe.Refuse as exc:
        raise Fail(exc.reason) from None
    except OSError as exc:
        raise Fail(mf.ERRNO.get(exc.errno, "failed")) from None
    return {"ok": True, "path": path}


def cmd_rotate(args):
    path = mf.abs_path(args[0] if args else "")
    degrees = int(args[1]) if len(args) > 1 else 0
    expect = args[args.index("--expect") + 1] if "--expect" in args[:-1] else None
    if degrees not in (90, 180, 270):
        raise Fail("usage")
    fmt = formats.magick_format(path)
    tool = shutil.which("magick")
    if not fmt or not tool:
        raise Fail("unsupported")
    target = os.path.realpath(path)
    # The installed checkout is not a picture library.
    import files_safe as safe

    try:
        if safe.protected(path) or safe.protected(target):
            raise Fail("protected")
    except safe.Refuse:
        raise Fail("badName") from None
    raw = mf.stat_file(target)
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
        raise Fail(mf.ERRNO.get(exc.errno, "failed")) from None
    return {"ok": True, "path": path, "mtime": str(done.st_mtime_ns), "size": done.st_size}


def cmd_copy(args):
    path = mf.abs_path(args[0] if args else "")
    st = mf.stat_file(path)
    if st.st_size > MAX_COPY:
        raise Fail("tooLarge")
    with open(path, "rb") as f:
        mf.wl_copy(f.read(MAX_COPY + 1), formats.mime(path) or "application/octet-stream")
    return {"ok": True}


COMMANDS = {
    "list": cmd_list,
    "info": cmd_info,
    "trash": cmd_trash,
    "rotate": cmd_rotate,
    "copy": cmd_copy,
    "copy-path": mf.cmd_copy_path,
}

if __name__ == "__main__":
    sys.exit(mf.run(COMMANDS, sys.argv))
