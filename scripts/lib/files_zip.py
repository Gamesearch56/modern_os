"""Zip and extract the files the window has selected. Members cannot escape."""

import os
import shutil
import stat
import sys
import zipfile

sys.path.insert(0, os.path.dirname(__file__))
import files_ops  # noqa: E402
import files_safe as safe  # noqa: E402

# Declared sizes can lie. Stop after this many bytes have been written.
_LIMIT = 2 * 1024 * 1024 * 1024


def _parts(name):
    text = str(name or "").replace("\\", "/").strip()
    if not text or text.startswith("/"):
        raise safe.Refuse("refused")
    parts = []
    for part in text.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            raise safe.Refuse("refused")
        parts.append(safe.leaf_name(part))
    if not parts:
        raise safe.Refuse("refused")
    return parts


def _inside(parent, path):
    try:
        parent = os.path.realpath(parent)
        path = os.path.realpath(path)
    except OSError:
        return False
    return path == parent or path.startswith(parent + os.sep)


def _add(archive, src, arc):
    if os.path.islink(src) or not os.path.isfile(src) and not os.path.isdir(src):
        return 0
    if os.path.isfile(src):
        archive.write(src, arc)
        return 1
    count = 0
    for dirpath, dirnames, filenames in os.walk(src, followlinks=False):
        dirnames[:] = [name for name in dirnames if not os.path.islink(os.path.join(dirpath, name))]
        rel = os.path.relpath(dirpath, src)
        base = arc if rel == "." else os.path.join(arc, rel)
        for name in filenames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue
            archive.write(full, os.path.join(base, name))
            count += 1
    return count


def cmd_pack(args):
    if len(args) < 2:
        files_ops.fail("usage")
    dest = safe.ensure_mutable(safe.clean(args[0]))
    if os.path.lexists(dest):
        files_ops.fail("taken")
    parent = safe.parent_of(dest)
    sources = []
    for raw in args[1:]:
        src = safe.clean(raw)
        if _inside(src, dest):
            files_ops.fail("refused")
        sources.append(src)
    count = 0
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for src in sources:
            count += _add(archive, src, os.path.basename(src))
    if count == 0:
        os.unlink(dest)
        files_ops.fail("refused")
    files_ops.emit({"path": dest})


def cmd_unpack(args):
    if len(args) != 2:
        files_ops.fail("usage")
    src = safe.clean(args[0])
    dest = safe.ensure_mutable(safe.clean(args[1]))
    if os.path.lexists(dest):
        files_ops.fail("taken")
    if not zipfile.is_zipfile(src):
        files_ops.fail("refused")
    os.mkdir(dest, 0o755)
    written = 0
    try:
        with zipfile.ZipFile(src) as archive:
            for info in archive.infolist():
                mode = info.external_attr >> 16
                if stat.S_ISLNK(mode):
                    raise safe.Refuse("refused")
                parts = _parts(info.filename)
                target = os.path.join(dest, *parts)
                if not _inside(dest, os.path.dirname(target) or dest):
                    raise safe.Refuse("refused")
                if info.is_dir() or str(info.filename).endswith("/"):
                    os.makedirs(target, exist_ok=True)
                    continue
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with archive.open(info) as incoming:
                    fd = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC, 0o644)
                    try:
                        while True:
                            chunk = incoming.read(1024 * 1024)
                            if not chunk:
                                break
                            written += len(chunk)
                            if written > _LIMIT:
                                raise safe.Refuse("refused")
                            os.write(fd, chunk)
                    finally:
                        os.close(fd)
    except Exception:
        shutil.rmtree(dest, ignore_errors=True)
        raise
    files_ops.emit({"path": dest})


def main(argv):
    commands = {"pack": cmd_pack, "unpack": cmd_unpack}
    if len(argv) < 2 or argv[1] not in commands:
        files_ops.fail("usage")
    try:
        commands[argv[1]](argv[2:])
    except safe.Refuse as exc:
        files_ops.fail(exc.reason)
    except zipfile.BadZipFile:
        files_ops.fail("refused")
    except FileExistsError:
        files_ops.fail("taken")
    except FileNotFoundError:
        files_ops.fail("missing")
    except OSError:
        files_ops.fail("refused")


if __name__ == "__main__":
    main(sys.argv)
