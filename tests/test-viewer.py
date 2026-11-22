#!/usr/bin/env python3
"""Imageviewer file layer: listing, facts, refusals, rotation, trash."""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts", "lib"))
import viewer_formats as formats  # noqa: E402

IO = os.path.join(ROOT, "scripts", "viewer-io.sh")
FAILS = []
HAVE_MAGICK = shutil.which("magick") is not None


def check(cond, msg):
    if cond:
        print("test-viewer: ok %s" % msg)
    else:
        print("test-viewer: FAIL %s" % msg, file=sys.stderr)
        FAILS.append(msg)


def io(*args, env=None):
    run = subprocess.run([IO, *args], capture_output=True, timeout=60, env=env)
    lines = run.stdout.decode("utf-8").strip().splitlines()
    return run.returncode, json.loads(lines[-1]) if lines else {}


def picture(path, size="4x2"):
    if HAVE_MAGICK:
        subprocess.run(["magick", "-size", size, "xc:red", path], check=True, timeout=30)
    else:
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n")


def dims(path):
    out = subprocess.run(["magick", "identify", "-format", "%w %h", path],
                         capture_output=True, timeout=30, check=True)
    return out.stdout.decode().strip()


def test_formats():
    check(formats.supported("A.JPG") and formats.supported("x.webp"), "extensions match without case")
    check(not formats.supported("notes.txt") and not formats.supported("noext"), "other files are not pictures")
    check(formats.mime("a.jpeg") == "image/jpeg", "jpeg has its mime type")
    check(formats.magick_format("a.svg") is None, "vector pictures are never rewritten")
    check(len(set(formats.mime_types())) == len(formats.mime_types()), "mime list has no repeats")


def test_list(tmp):
    for name in ("img10.png", "img2.png", "b[0].jpg", ".hidden.png"):
        picture(os.path.join(tmp, name))
    open(os.path.join(tmp, "notes.txt"), "w").close()
    code, out = io("list", os.path.join(tmp, "img2.png"))
    names = [os.path.basename(p) for p in out.get("items", [])]
    check(code == 0 and names == ["b[0].jpg", "img2.png", "img10.png"], "one picture lists its folder in natural order")
    check(out.get("index") == 1, "the opened picture is the current one")
    code, out = io("list", os.path.join(tmp, ".hidden.png"))
    names = [os.path.basename(p) for p in out.get("items", [])]
    check(".hidden.png" in names and names[out["index"]] == ".hidden.png", "a hidden picture opened directly is kept")
    code, out = io("list", os.path.join(tmp, "notes.txt"))
    check(out.get("ok") and os.path.basename(out["items"][out["index"]]) == "notes.txt",
          "an opened file of another type is still offered")
    code, out = io("list", tmp)
    check(out.get("ok") and out.get("index") == 0 and len(out["items"]) == 3, "a folder lists its pictures")
    sub = os.path.join(tmp, "sub")
    os.mkdir(sub)
    picture(os.path.join(sub, "z.png"))
    code, out = io("list", os.path.join(tmp, "img10.png"), sub)
    names = [os.path.basename(p) for p in out.get("items", [])]
    check(names == ["img10.png", "z.png"], "several paths keep their order and expand folders")
    empty = os.path.join(tmp, "empty")
    os.mkdir(empty)
    check(io("list", empty)[1].get("error") == "empty", "an empty folder says so")
    check(io("list", os.path.join(tmp, "gone.png"))[1].get("error") == "missing", "a missing file says so")
    check(io("list", "relative.png")[1].get("error") == "badName", "a relative path is refused")
    check(io("list", "/dev/null")[1].get("error") == "special", "a device is refused")
    code, out = io("list", "file://" + os.path.join(tmp, "img2.png"))
    check(out.get("ok") is True, "a file:// path lists")


def test_info(tmp):
    path = os.path.join(tmp, "img2.png")
    code, out = io("info", path)
    check(code == 0 and out.get("mime") == "image/png" and out.get("size") == os.path.getsize(path), "facts match the file")
    check(out.get("mtime") == str(os.stat(path).st_mtime_ns), "mtime is exact, as a string")
    check(io("info", tmp)[1].get("error") == "directory", "a folder has no picture facts")


def test_rotate(tmp):
    if not HAVE_MAGICK:
        check(True, "magick not installed; rotation checks skipped")
        return
    path = os.path.join(tmp, "b[0].jpg")
    picture(path, "40x20")
    mtime = str(os.stat(path).st_mtime_ns)
    os.chmod(path, 0o640)
    code, out = io("rotate", path, "90", "--expect", mtime)
    check(code == 0 and out.get("ok") and dims(path) == "20 40", "a bracketed name rotates in place")
    check(oct(os.stat(path).st_mode & 0o777) == "0o640", "rotation keeps the file mode")
    check(io("rotate", path, "90", "--expect", mtime)[1].get("error") == "changed",
          "a picture changed since it was shown is not overwritten")
    check(dims(path) == "20 40", "the refused rotation left the file alone")
    check(io("rotate", path, "45")[1].get("error") == "usage", "only quarter turns are allowed")
    svg = os.path.join(tmp, "v.svg")
    with open(svg, "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="2" height="1"/>')
    check(io("rotate", svg, "90")[1].get("error") == "unsupported", "a vector picture is not rewritten")
    locked = os.path.join(tmp, "locked.png")
    picture(locked)
    os.chmod(locked, 0o444)
    if os.geteuid() != 0:
        check(io("rotate", locked, "180")[1].get("error") == "denied", "a read-only picture is refused")
    check(io("info", locked)[1].get("writable") is False, "a read-only picture says so")


def test_trash(tmp):
    home = os.path.join(tmp, "home")
    os.makedirs(home)
    path = os.path.join(home, "pic.png")
    picture(path)
    env = dict(os.environ, HOME=home, XDG_DATA_HOME=os.path.join(home, ".local", "share"))
    code, out = io("trash", path, env=env)
    trashed = os.path.join(home, ".local", "share", "Trash", "files", "pic.png")
    check(code == 0 and out.get("ok") and not os.path.exists(path) and os.path.exists(trashed),
          "trash moves the picture into the trash")
    check(os.path.exists(trashed[:-len("files/pic.png")] + "info/pic.png.trashinfo"), "trash writes its restore note")
    check(io("trash", path, env=env)[1].get("ok") is False, "trashing a gone picture fails cleanly")


def test_usage():
    code, out = io()
    check(code == 2 and out.get("error") == "usage", "no command is a usage error")
    code, out = io("explode", "/x")
    check(code == 2 and out.get("error") == "usage", "an unknown command is a usage error")


def main():
    tmp = tempfile.mkdtemp(prefix="modern-viewer-")
    try:
        test_formats()
        test_list(tmp)
        test_info(tmp)
        test_rotate(tmp)
        test_trash(tmp)
        test_usage()
    finally:
        for dirpath, _dirs, files in os.walk(tmp):
            for name in files:
                try:
                    os.chmod(os.path.join(dirpath, name), 0o644)
                except OSError:
                    pass
        shutil.rmtree(tmp, ignore_errors=True)
    if FAILS:
        print("test-viewer: %d failed" % len(FAILS), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
