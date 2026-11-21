#!/usr/bin/env python3
"""Texteditor file layer: byte-exact round trips, refusals, safe saves, claims."""
import json
import os
import stat
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts", "lib"))
import editor_claim as claim  # noqa: E402
import editor_codec as codec  # noqa: E402

IO = os.path.join(ROOT, "scripts", "editor-io.sh")
FAILS = []


def check(cond, msg):
    if cond:
        print("test-editor: ok %s" % msg)
    else:
        print("test-editor: FAIL %s" % msg, file=sys.stderr)
        FAILS.append(msg)


def refused(fn, reason):
    try:
        fn()
    except codec.Refuse as exc:
        return exc.reason == reason
    return False


def io(*args, stdin=None, env=None):
    run = subprocess.run([IO, *args], input=(stdin or "").encode("utf-8"),
                         capture_output=True, timeout=10, env=env)
    return run.returncode, json.loads(run.stdout.decode("utf-8").strip().splitlines()[-1])


def roundtrip(data):
    doc = codec.decode(data)
    return codec.encode(doc["text"], doc["encoding"], doc["eol"], doc["standIn"]) == data, doc


def test_codec():
    for label, data in (
        ("utf-8 lf", "Grüße\nzwei\n".encode()),
        ("crlf", b"a\r\nb\r\n"),
        ("cr", b"a\rb\r"),
        ("utf-8 bom", b"\xef\xbb\xbf" + "Ä\n".encode()),
        ("utf-16le", b"\xff\xfe" + "Ä€\r\n".encode("utf-16-le")),
        ("utf-16be", b"\xfe\xff" + "Ä€\n".encode("utf-16-be")),
        ("windows-1252", "Preis 5 € – fertig\n".encode("cp1252")),
        ("iso-8859-1", b"caf\xe9 \x81\n"),
        ("nbsp", "a\u00a0b\n".encode()),
        ("empty", b""),
    ):
        same, doc = roundtrip(data)
        check(same, "%s survives load and save byte for byte (%s)" % (label, doc["encoding"]))
    check(codec.decode(b"a\r\nb\r\n")["eol"] == "crlf", "crlf is detected")
    check(codec.decode(b"a\rb\r")["eol"] == "cr", "cr is detected")
    check(codec.decode(b"a\r\nb\nc\n")["mixed"], "mixed line endings are flagged")
    check(codec.decode(b"plain")["eol"] == "lf", "a single line defaults to lf")
    nb = codec.decode("a\u00a0b".encode())
    check(nb["standIn"] and "\u00a0" not in nb["text"], "NBSP is swapped for a stand-in the TextEdit keeps")
    check(codec.decode("a\u00a0b\u2007".encode())["lossy"], "NBSP next to FIGURE SPACE opens read-only")
    check(codec.decode("a\u2028b".encode())["lossy"], "a line separator opens read-only")
    check(not codec.decode(b"col\tcol\x1b[0m\x0c\n")["lossy"], "tabs, escapes, and form feeds are text")
    check(refused(lambda: codec.decode(b"ab\x00cd"), "binary"), "a NUL byte is refused as binary")
    check(refused(lambda: codec.decode(bytes(range(1, 32)) * 4), "binary"), "control-heavy bytes are refused")
    check(refused(lambda: codec.encode("€", "iso-8859-1", "lf", False), "unencodable"),
          "a character outside the encoding is refused, not dropped")
    check(refused(lambda: codec.encode("x", "utf-7", "lf", False), "encoding"), "an unknown encoding is refused")
    check(refused(lambda: codec.encode("x", "utf-8", "lfcr", False), "eol"), "an unknown line ending is refused")
    check(codec.encode("a\nb", "utf-8", "crlf", False) == b"a\r\nb", "lf text is written with crlf")


def test_io(tmp):
    box = os.path.join(tmp, "box")
    os.makedirs(box)
    f = os.path.join(box, "note.txt")
    with open(f, "wb") as h:
        h.write("Zeile\u00a0eins\r\nzwei\r\n".encode())
    os.chmod(f, 0o640)
    code, out = io("load", f)
    check(code == 0 and out["ok"] and out["eol"] == "crlf" and out["standIn"], "load reports text, eol, and stand-in")
    check(isinstance(out["mtime"], str) and out["mtime"].isdigit(), "mtime is a decimal string")
    _, again = io("save", f, "--encoding", out["encoding"], "--eol", out["eol"], "--stand-in",
                  "--expect", out["mtime"], stdin=out["text"])
    with open(f, "rb") as h:
        check(again["ok"] and h.read() == "Zeile\u00a0eins\r\nzwei\r\n".encode(), "an unchanged save rewrites the same bytes")
    check(stat.S_IMODE(os.stat(f).st_mode) == 0o640, "an atomic save keeps the file mode")
    check(not [n for n in os.listdir(box) if n.endswith(".tmp")], "no temporary file is left behind")
    _, stale = io("save", f, "--expect", "1", stdin="lost")
    with open(f, "rb") as h:
        check(stale.get("error") == "changed" and b"lost" not in h.read(), "a save over a newer file is refused")
    check(io("save", f, "--no-clobber", stdin="x")[1].get("error") == "exists", "Save as never replaces silently")
    check(io("load", f, "--max-bytes", "4")[1].get("error") == "tooLarge", "an oversized file is refused")
    check(io("load", box)[1].get("error") == "directory", "a folder is refused")
    check(io("load", os.path.join(box, "nope"))[1].get("error") == "missing", "a missing file is reported")
    check(io("load", "relative.txt")[1].get("error") == "badName", "a relative path is refused")
    fifo = os.path.join(box, "pipe")
    os.mkfifo(fifo)
    check(io("load", fifo)[1].get("error") == "special", "a FIFO is refused without blocking")
    with open(os.path.join(box, "bin"), "wb") as h:
        h.write(b"\x7fELF\x00\x00")
    check(io("load", os.path.join(box, "bin"))[1].get("error") == "binary", "a binary file is refused")
    link = os.path.join(box, "hard.txt")
    os.link(f, link)
    inode = os.stat(f).st_ino
    io("save", link, stdin="both\n")
    with open(f) as h:
        check(os.stat(link).st_ino == inode and h.read() == "both\n", "a hard-linked file is written in place")
    os.unlink(link)
    sym = os.path.join(box, "sym.txt")
    os.symlink(f, sym)
    io("save", sym, stdin="via link\n")
    with open(f) as h:
        check(os.path.islink(sym) and h.read() == "via link\n", "saving through a symlink keeps the link")
    ro = os.path.join(box, "ro.txt")
    with open(ro, "w") as h:
        h.write("keep\n")
    os.chmod(ro, 0o444)
    with open(ro) as h:
        check(io("save", ro, stdin="x")[1].get("error") == "denied" and h.read() == "keep\n",
              "a read-only file is not replaced")
    fresh = os.path.join(box, "new.txt")
    old = os.umask(0o027)
    try:
        io("save", fresh, stdin="neu")
    finally:
        os.umask(old)
    check(stat.S_IMODE(os.stat(fresh).st_mode) == 0o640, "a new file follows the umask")
    run = subprocess.run([IO, "frobnicate"], capture_output=True, timeout=10)
    check(run.returncode == 2, "an unknown command is a usage error")
    home = os.path.join(tmp, "home")
    victim = os.path.join(home, "bye.txt")
    os.makedirs(home)
    with open(victim, "w") as h:
        h.write("bye\n")
    env = dict(os.environ, HOME=home, XDG_DATA_HOME=os.path.join(tmp, "data"))
    _, gone = io("trash", victim, env=env)
    check(gone["ok"] and not os.path.exists(victim)
          and os.path.exists(os.path.join(tmp, "data", "Trash", "files", "bye.txt")), "trash moves the file to the trash")


def test_claim(tmp):
    os.environ["MODERN_EDITOR_RUNTIME"] = os.path.join(tmp, "run")
    os.environ["MODERN_EDITOR_ANY_PID"] = "1"
    doc = os.path.join(tmp, "doc.txt")
    me, parent = os.getpid(), os.getppid()
    check(claim.owner(doc)["pid"] == 0, "an unopened file has no owner")
    check(claim.claim(doc, me)["ok"], "the first window claims the file")
    second = claim.claim(doc, parent)
    check(not second["ok"] and second.get("pid") == me, "a second window learns who has it open")
    claim.release(doc, parent)
    check(claim.owner(doc)["pid"] == me, "only the owner can release")
    claim.release(doc, me)
    check(claim.owner(doc)["pid"] == 0, "release frees the file")
    dead = subprocess.Popen(["true"])
    dead.wait()
    claim.claim(doc, dead.pid)
    check(claim.claim(doc, me)["ok"], "a claim from a dead window is taken over")
    del os.environ["MODERN_EDITOR_ANY_PID"]
    check(claim.owner(doc)["pid"] == 0, "a live process that is not an editor holds nothing")


def main():
    with tempfile.TemporaryDirectory(prefix="modern-editor-") as tmp:
        test_codec()
        test_io(tmp)
        test_claim(tmp)
        for root, dirs, files in os.walk(tmp):
            for name in files:
                os.chmod(os.path.join(root, name), 0o600)
    if FAILS:
        sys.exit(1)


if __name__ == "__main__":
    main()
