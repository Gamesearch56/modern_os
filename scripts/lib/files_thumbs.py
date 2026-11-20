"""Freedesktop thumbnails for images, videos, and PDF files.

The cache is ``$XDG_CACHE_HOME/thumbnails/large`` so a later cleanup of
regenerable thumbnails removes these too. A hit is reused only when the
stored mtime still matches the file.
"""

import concurrent.futures
import hashlib
import os
import shutil
import struct
import subprocess
import sys
import threading
import urllib.parse
import zlib

EDGE = 256
IMAGES = {
    "jpg", "jpeg", "jpe", "png", "gif", "webp", "bmp", "tif", "tiff",
    "avif", "heic", "heif", "jxl", "svg", "ico",
}
VIDEOS = {
    "mp4", "m4v", "mkv", "webm", "mov", "avi", "mpg", "mpeg", "wmv",
    "flv", "ogv", "3gp", "m2ts", "ts",
}
DOCS = {"pdf", "ps", "eps"}

_PRINT = threading.Lock()


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    path = os.path.join(base, "thumbnails", "large")
    os.makedirs(path, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def file_uri(path):
    return "file://" + urllib.parse.quote(os.path.abspath(path), safe="/")


def thumb_path(path, edge=EDGE):
    digest = hashlib.md5(file_uri(path).encode("utf-8")).hexdigest()
    # The grid and the preview ask for different sizes. They must not
    # share one file or the smaller picture replaces the larger one.
    name = digest + ".png" if edge == EDGE else digest + "-" + str(edge) + ".png"
    return os.path.join(cache_dir(), name)


def extension(path):
    return os.path.splitext(os.path.basename(path))[1].lower().lstrip(".")


def kind_of(path):
    ext = extension(path)
    if ext in IMAGES:
        return "image"
    if ext in VIDEOS:
        return "video"
    if ext in DOCS:
        return "file"
    return ""


def _chunk(tag, data):
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def _text_chunk(key, value):
    raw = key.encode("latin1") + b"\x00" + str(value).encode("latin1", "replace")
    return _chunk(b"tEXt", raw)


def stamp(png, uri, mtime):
    marker = b"\x00\x00\x00\x00IEND"
    at = png.rfind(marker)
    if at < 0:
        return png
    extra = _text_chunk("Thumb::URI", uri) + _text_chunk("Thumb::MTime", int(mtime))
    return png[:at] + extra + png[at:]


def read_mtime(path):
    try:
        handle = open(path, "rb")
    except OSError:
        return None
    with handle:
        if handle.read(8) != b"\x89PNG\r\n\x1a\n":
            return None
        found = None
        while True:
            header = handle.read(8)
            if len(header) < 8:
                return found
            length = int.from_bytes(header[:4], "big")
            tag = header[4:8]
            if length > 1_000_000:
                return found
            data = handle.read(length)
            handle.read(4)
            if tag == b"IEND":
                return found
            if tag == b"tEXt" and data.startswith(b"Thumb::MTime\x00"):
                found = data.split(b"\x00", 1)[1].decode("latin1", "replace")
    return None


def fresh(path, mtime):
    found = read_mtime(path)
    if found is None:
        return False
    try:
        return int(float(found)) == int(mtime)
    except (TypeError, ValueError):
        return False


def _run(cmd):
    try:
        done = subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return done.returncode == 0


def _written(dest):
    try:
        return os.path.isfile(dest) and os.path.getsize(dest) > 0
    except OSError:
        return False


def render_image(src, dest, edge=EDGE):
    if shutil.which("magick"):
        shown = src.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]") + "[0]"
        if _run(["magick", shown, "-auto-orient", "-thumbnail", str(edge) + "x" + str(edge) + ">", "-background", "none", "-strip", "png:" + dest]) and _written(dest):
            return True
        try:
            os.remove(dest)
        except OSError:
            pass
    if shutil.which("ffmpeg"):
        scale = "scale=" + str(edge) + ":" + str(edge) + ":force_original_aspect_ratio=decrease"
        if _run(["ffmpeg", "-y", "-i", src, "-frames:v", "1", "-update", "1", "-vf", scale, dest]) and _written(dest):
            return True
    return False


def _drop(path):
    try:
        os.remove(path)
    except OSError:
        pass


def render_video(src, dest, edge=EDGE):
    # ffmpegthumbnailer picks a frame from a normal movie. A clip shorter
    # than that seek still needs a picture, so ffmpeg grabs the first frame.
    if shutil.which("ffmpegthumbnailer"):
        if _run(["ffmpegthumbnailer", "-i", src, "-o", dest, "-s", str(edge), "-c", "png", "-q", "8"]) and _written(dest):
            return True
        _drop(dest)
    if not shutil.which("ffmpeg"):
        return False
    for start in ("0", "1"):
        scale = "scale=" + str(edge) + ":" + str(edge) + ":force_original_aspect_ratio=decrease"
        cmd = ["ffmpeg", "-y", "-ss", start, "-i", src, "-frames:v", "1", "-update", "1", "-vf", scale, dest]
        if _run(cmd) and _written(dest):
            return True
        _drop(dest)
    return False


def render_doc(src, dest, edge=EDGE):
    # The first page is the preview. pdftoppm keeps a PDF out of ImageMagick.
    if extension(src) == "pdf" and shutil.which("pdftoppm"):
        stem = dest + ".page"
        if _run(["pdftoppm", "-png", "-f", "1", "-l", "1", "-singlefile", "-scale-to", str(edge), src, stem]) and _written(stem + ".png"):
            os.replace(stem + ".png", dest)
            return True
        _drop(stem + ".png")
    return render_image(src, dest, edge)


def render(src, dest, kind, edge=EDGE):
    if kind == "video":
        return render_video(src, dest, edge)
    if extension(src) in DOCS:
        return render_doc(src, dest, edge)
    return render_image(src, dest, edge)


def publish(src, dest, mtime):
    tmp = dest + ".partial"
    try:
        with open(tmp, "rb") as handle:
            raw = handle.read()
        os.remove(tmp)
    except OSError:
        return False
    stamped = stamp(raw, file_uri(src), mtime)
    try:
        fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    except OSError:
        return False
    with os.fdopen(fd, "wb") as handle:
        handle.write(stamped)
    return fresh(dest, mtime)


def one(src, edge=EDGE):
    if not src or "\n" in src or "\t" in src:
        return
    kind = kind_of(src)
    if not kind:
        return
    try:
        st = os.stat(src)
    except OSError:
        return
    if not os.path.isfile(src):
        return
    dest = thumb_path(src, edge)
    if fresh(dest, st.st_mtime):
        emit(src, dest)
        return
    partial = dest + ".partial"
    if not render(src, partial, kind, edge):
        try:
            os.remove(partial)
        except OSError:
            pass
        return
    if publish(src, dest, st.st_mtime):
        emit(src, dest)


def emit(src, dest):
    with _PRINT:
        sys.stdout.write(src + "\t" + dest + "\n")
        sys.stdout.flush()


def paths_from(argv):
    if len(argv) > 1:
        return argv[1:]
    return [line.rstrip("\n") for line in sys.stdin if line.strip()]


def main(argv):
    edge = EDGE
    args = list(argv)
    if "--edge" in args:
        at = args.index("--edge")
        edge = int(args[at + 1])
        del args[at:at + 2]
        if edge < 16 or edge > 2048:
            return 1
    rows = []
    seen = set()
    for path in paths_from(args):
        if path and path not in seen:
            seen.add(path)
            rows.append(path)
    if not rows:
        return 0
    cache_dir()
    workers = min(4, len(rows))
    if len(rows) == 1:
        one(rows[0], edge)
        return 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        list(pool.map(lambda path: one(path, edge), rows))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
