"""File access for the ModernOS Mediaplayer. One JSON object per call.

  list PATH...                  what to play: one video opens the videos in
                                its folder (one song, the songs), starting there
  info PATH                     size, type, kind (video/audio)
  frame PATH MILLISECONDS DIR   save the frame at that time as a PNG in DIR
  copy-path PATH                the path to the clipboard

Playback itself is Qt Multimedia's; nothing here decodes a stream.
"""

import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import media_files as mf  # noqa: E402
import player_formats as formats  # noqa: E402

MAX_FRAME = 64 * 1024 * 1024
Fail = mf.Fail


def cmd_list(args):
    def same_kind(path):
        want = formats.kind(path)
        return lambda name: formats.supported(name) and (not want or formats.kind(name) == want)

    return mf.list_paths(args, formats.supported, siblings=same_kind)


def cmd_info(args):
    path = mf.abs_path(args[0] if args else "")
    st = mf.stat_file(path)
    return {"ok": True, "path": path, "size": st.st_size, "mime": formats.mime(path), "kind": formats.kind(path)}


def _clock(ms):
    s = ms // 1000
    return "%02d-%02d-%02d" % (s // 3600, s // 60 % 60, s % 60)


def _create(folder, stem, data):
    """A new file next to nothing it could overwrite: O_EXCL, numbered on a clash."""
    for n in range(1, 1000):
        name = "%s.png" % stem if n == 1 else "%s %d.png" % (stem, n)
        target = os.path.join(folder, name)
        try:
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        except FileExistsError:
            continue
        try:
            os.write(fd, data)
            os.fsync(fd)
        finally:
            os.close(fd)
        return target
    raise Fail("full")


def cmd_frame(args):
    path = mf.abs_path(args[0] if args else "")
    ms = int(args[1]) if len(args) > 1 else -1
    folder = mf.abs_path(args[2] if len(args) > 2 else "")
    if ms < 0:
        raise Fail("usage")
    mf.stat_file(path)
    if formats.kind(path) != "video":
        raise Fail("unsupported")
    tool = shutil.which("ffmpeg")
    if not tool:
        raise Fail("unsupported")
    try:
        os.makedirs(folder, exist_ok=True)
    except OSError as exc:
        raise Fail(mf.ERRNO.get(exc.errno, "failed")) from None
    if not os.path.isdir(folder) or os.path.islink(folder):
        raise Fail("directory")
    # "file:" keeps a name with ":" from being read as a protocol; the PNG
    # comes back on a pipe, so ffmpeg never opens an output path.
    run = subprocess.run([tool, "-nostdin", "-hide_banner", "-loglevel", "error", "-ss", "%.3f" % (ms / 1000),
                          "-i", "file:" + path, "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-"],
                         capture_output=True, timeout=60)
    if run.returncode != 0 or not run.stdout or len(run.stdout) > MAX_FRAME:
        raise Fail("failed")
    stem = os.path.splitext(os.path.basename(path))[0][:120] + " " + _clock(ms)
    try:
        saved = _create(folder, stem, run.stdout)
    except OSError as exc:
        raise Fail(mf.ERRNO.get(exc.errno, "failed")) from None
    return {"ok": True, "path": saved}


COMMANDS = {
    "list": cmd_list,
    "info": cmd_info,
    "frame": cmd_frame,
    "copy-path": mf.cmd_copy_path,
}

if __name__ == "__main__":
    sys.exit(mf.run(COMMANDS, sys.argv))
