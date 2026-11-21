#!/usr/bin/env python3
"""Mediaplayer file layer: playlists, facts, refusals, saved frames."""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts", "lib"))
import player_formats as formats  # noqa: E402

IO = os.path.join(ROOT, "scripts", "player-io.sh")
FAILS = []
HAVE_FFMPEG = shutil.which("ffmpeg") is not None


def check(cond, msg):
    if cond:
        print("test-player: ok %s" % msg)
    else:
        print("test-player: FAIL %s" % msg, file=sys.stderr)
        FAILS.append(msg)


def io(*args):
    run = subprocess.run([IO, *args], capture_output=True, timeout=90)
    lines = run.stdout.decode("utf-8").strip().splitlines()
    return run.returncode, json.loads(lines[-1]) if lines else {}


def touch(path):
    with open(path, "wb") as f:
        f.write(b"\0")


def clip(path):
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i",
                    "testsrc=duration=2:size=64x48:rate=10", "-pix_fmt", "yuv420p", path],
                   check=True, timeout=60)


def test_formats():
    check(formats.supported("A.MKV") and formats.supported("x.opus"), "extensions match without case")
    check(not formats.supported("notes.txt") and not formats.supported("noext"), "other files are not media")
    check(formats.kind("a.webm") == "video" and formats.kind("a.flac") == "audio", "video and audio are told apart")
    check(formats.mime("a.mp4") == "video/mp4", "mp4 has its mime type")
    check(len(set(formats.mime_types())) == len(formats.mime_types()), "mime list has no repeats")


def test_list(tmp):
    for name in ("ep10.mkv", "ep2.mkv", "ep2.extra.mkv", "clip.mp4", "clip2.mp4", "song.mp3", ".hidden.mp4", "notes.txt"):
        touch(os.path.join(tmp, name))
    code, out = io("list", os.path.join(tmp, "ep2.mkv"))
    names = [os.path.basename(p) for p in out.get("items", [])]
    check(code == 0 and names == ["clip.mp4", "clip2.mp4", "ep2.mkv", "ep2.extra.mkv", "ep10.mkv"],
          "one video lists the videos of its folder in natural order")
    check(names[out.get("index", -1)] == "ep2.mkv", "the opened video is the current one")
    code, out = io("list", os.path.join(tmp, "song.mp3"))
    check([os.path.basename(p) for p in out.get("items", [])] == ["song.mp3"], "a song lists songs, not videos")
    code, out = io("list", os.path.join(tmp, ".hidden.mp4"))
    names = [os.path.basename(p) for p in out.get("items", [])]
    check(names[out.get("index", -1)] == ".hidden.mp4", "a hidden video opened directly is kept")
    code, out = io("list", tmp)
    check(out.get("ok") and len(out["items"]) == 6 and out.get("index") == 0, "a folder lists all its media")
    empty = os.path.join(tmp, "empty")
    os.mkdir(empty)
    check(io("list", empty)[1].get("error") == "empty", "an empty folder says so")
    check(io("list", os.path.join(tmp, "gone.mp4"))[1].get("error") == "missing", "a missing file says so")
    check(io("list", "relative.mp4")[1].get("error") == "badName", "a relative path is refused")
    check(io("list", "/dev/null")[1].get("error") == "special", "a device is refused")
    check(io("list", "file://" + os.path.join(tmp, "clip.mp4"))[1].get("ok") is True, "a file:// path lists")


def test_info(tmp):
    path = os.path.join(tmp, "clip.mp4")
    code, out = io("info", path)
    check(code == 0 and out.get("kind") == "video" and out.get("size") == 1, "facts match the file")
    check(io("info", tmp)[1].get("error") == "directory", "a folder has no media facts")


def test_frame(tmp):
    shots = os.path.join(tmp, "Pictures", "Screenshots")
    check(io("frame", os.path.join(tmp, "song.mp3"), "0", shots)[1].get("error") == "unsupported",
          "a song has no frame to save")
    check(io("frame", os.path.join(tmp, "clip.mp4"), "-5", shots)[1].get("error") == "usage", "a negative time is refused")
    check(io("frame", os.path.join(tmp, "clip.mp4"), "0", "Pictures")[1].get("error") == "badName",
          "a relative target folder is refused")
    link = os.path.join(tmp, "linked")
    os.symlink(tmp, link)
    if not HAVE_FFMPEG:
        check(True, "ffmpeg not installed; frame checks skipped")
        return
    video = os.path.join(tmp, "a:b [1].mp4")
    clip(video)
    code, first = io("frame", video, "1000", shots)
    check(code == 0 and first.get("ok") and first["path"].endswith("a:b [1] 00-00-01.png"),
          "a name with : and [ ] saves a frame named after the time")
    with open(first.get("path", "/dev/null"), "rb") as f:
        check(f.read(8) == b"\x89PNG\r\n\x1a\n", "the saved frame is a PNG")
    code, second = io("frame", video, "1000", shots)
    check(second.get("path", "").endswith("00-00-01 2.png") and os.path.exists(first["path"]),
          "a second frame at the same time never overwrites the first")
    check(io("frame", video, "0", link)[1].get("error") == "directory", "a linked target folder is refused")


def test_usage():
    code, out = io()
    check(code == 2 and out.get("error") == "usage", "no command is a usage error")
    code, out = io("rotate", "/x", "90")
    check(code == 2 and out.get("error") == "usage", "a viewer-only command is unknown here")


def main():
    tmp = tempfile.mkdtemp(prefix="modern-player-")
    try:
        test_formats()
        test_list(tmp)
        test_info(tmp)
        test_frame(tmp)
        test_usage()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if FAILS:
        print("test-player: %d failed" % len(FAILS), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
