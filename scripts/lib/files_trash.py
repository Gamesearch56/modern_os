"""XDG trash. Only this user's trash directory is emptied."""

import errno
import json
import os
import stat
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(__file__))
import files_ops  # noqa: E402
import files_places as places  # noqa: E402
import files_safe as safe  # noqa: E402


def fail(reason):
    print(reason, file=sys.stderr)
    raise SystemExit(1)


def emit(obj):
    json.dump(obj, sys.stdout)
    sys.stdout.write("\n")


def _real_dir(path):
    # A trash folder that is a symlink would empty or fill some other tree.
    if os.path.islink(path):
        raise safe.Refuse("refused")
    os.makedirs(path, exist_ok=True)
    if os.path.islink(path) or not os.path.isdir(path):
        raise safe.Refuse("refused")
    return path


def trash_root():
    data = os.environ.get("XDG_DATA_HOME") or os.path.join(safe.home_dir(), ".local", "share")
    root = _real_dir(os.path.join(data, "Trash"))
    _real_dir(os.path.join(root, "files"))
    _real_dir(os.path.join(root, "info"))
    return root


def mount_of(path):
    path = safe.clean(path)
    best = "/"
    try:
        lines = open("/proc/self/mountinfo", encoding="utf-8", errors="replace")
    except OSError:
        return best
    with lines:
        for line in lines:
            parts = line.split()
            if len(parts) < 5:
                continue
            point = parts[4].replace("\\040", " ").replace("\\011", "\t")
            if point != "/" and path != point and not path.startswith(point + "/"):
                continue
            if len(point) > len(best):
                best = point
    return best


def trash_for(src):
    # Same filesystem means the move is one rename. Another disk gets its
    # own trash directory so a large folder is not copied home first.
    home = trash_root()
    try:
        if os.lstat(src).st_dev == os.lstat(os.path.join(home, "files")).st_dev:
            return home
    except OSError:
        return home
    mount = mount_of(src)
    if safe.protected(mount):
        return home
    root = os.path.join(mount, ".Trash-" + str(os.getuid()))
    try:
        if not os.path.lexists(root):
            os.mkdir(root, 0o700)
        st = os.lstat(root)
    except OSError:
        return home
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
        return home
    if st.st_uid != os.getuid() or (st.st_mode & 0o022):
        return home
    try:
        for sub in ("files", "info"):
            _real_dir(os.path.join(root, sub))
    except (OSError, safe.Refuse):
        return home
    return root


def _write_info(info_dir, name, original):
    tmp = "." + name + ".part"
    info = name + ".trashinfo"
    body = (
        "[Trash Info]\nPath="
        + urllib.parse.quote(original)
        + "\nDeletionDate="
        + time.strftime("%Y-%m-%dT%H:%M:%S")
        + "\n"
    )
    fd = os.open(
        tmp,
        os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o600,
        dir_fd=info_dir,
    )
    try:
        os.write(fd, body.encode())
    finally:
        os.close(fd)
    safe.rename_noreplace(info_dir, tmp, info_dir, info)


def trash_one(src):
    src = safe.ensure_mutable(safe.clean(src))
    if not os.path.lexists(src):
        raise FileNotFoundError(src)
    root = trash_for(src)
    src_dir, src_name = safe.open_parent(src)
    dst_dir = safe.open_dir(os.path.join(root, "files"), True)
    info_dir = safe.open_dir(os.path.join(root, "info"), True)
    try:
        base = safe.leaf_name(src_name)
        stem, ext = os.path.splitext(base)
        stored = None
        for n in range(0, 1000):
            cand = base if n == 0 else f"{stem} {n + 1}{ext}"
            try:
                safe.rename_noreplace(src_dir, src_name, dst_dir, cand)
                stored = cand
                break
            except FileExistsError:
                continue
            except OSError as exc:
                if exc.errno != errno.EXDEV:
                    raise
                copied = safe.copy_into(src, os.path.join(root, "files"))
                safe.remove_path(src)
                stored = os.path.basename(copied)
                break
        if stored is None:
            raise FileExistsError(base)
        _write_info(info_dir, stored, src)
    finally:
        os.close(src_dir)
        os.close(dst_dir)
        os.close(info_dir)


def cmd_move(args):
    if not args:
        fail("usage")
    reason = None
    count = 0
    for src in args:
        try:
            trash_one(src)
            places.shift_drop([src])
            count += 1
        except safe.Refuse as exc:
            reason = reason or exc.reason
        except FileNotFoundError:
            reason = reason or "missing"
        except FileExistsError:
            reason = reason or "exists"
        except OSError:
            reason = reason or "refused"
    if reason:
        fail(reason)
    emit({"ok": True, "count": count})


def read_info(path):
    original = ""
    when = ""
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("Path="):
                original = urllib.parse.unquote(line[5:].strip())
            elif line.startswith("DeletionDate="):
                when = line.split("=", 1)[1].strip()
    return original, when


def cmd_list(_args):
    root = trash_root()
    rows = []
    info_dir = os.path.join(root, "info")
    for name in sorted(os.listdir(info_dir)):
        if not name.endswith(".trashinfo"):
            continue
        key = name[: -len(".trashinfo")]
        original, when = read_info(os.path.join(info_dir, name))
        stored = os.path.join(root, "files", key)
        try:
            row = files_ops.entry(stored)
        except OSError:
            row = {
                "name": key,
                "path": stored,
                "dir": False,
                "size": -1,
                "mtime": 0,
                "created": 0,
                "kind": "file",
            }
        row["original"] = original
        row["when"] = when
        rows.append(row)
    emit(rows)


def cmd_restore(args):
    key = args[0] if args else ""
    if not key or "/" in key or "\0" in key or "\n" in key or key in (".", ".."):
        fail("bad-path")
    root = trash_root()
    stored = os.path.join(root, "files", key)
    info = os.path.join(root, "info", key + ".trashinfo")
    if not os.path.lexists(stored) or os.path.islink(info) or not os.path.isfile(info):
        fail("missing")
    original, _when = read_info(info)
    dest = safe.ensure_mutable(safe.clean(original))
    parent = safe.parent_of(dest)
    if not os.path.isdir(parent):
        fail("missing")
    src_dir, src_name = safe.open_parent(stored)
    dst_dir, dest_name = safe.open_parent(dest)
    try:
        try:
            safe.rename_noreplace(src_dir, src_name, dst_dir, dest_name)
        except OSError as exc:
            if exc.errno != errno.EXDEV:
                raise
            safe.copy_into(stored, parent)
            safe.remove_path(stored)
    finally:
        os.close(src_dir)
        os.close(dst_dir)
    os.unlink(info)
    emit({"path": dest})


def cmd_empty(_args):
    root = trash_root()
    for folder in ("files", "info"):
        path = os.path.join(root, folder)
        for name in os.listdir(path):
            if name in (".", ".."):
                continue
            safe.remove_path(os.path.join(path, name))
    emit({"ok": True})


def main(argv):
    commands = {"move": cmd_move, "list": cmd_list, "restore": cmd_restore, "empty": cmd_empty}
    if len(argv) < 2 or argv[1] not in commands:
        fail("usage")
    try:
        commands[argv[1]](argv[2:])
    except safe.Refuse as exc:
        fail(exc.reason)
    except FileExistsError:
        fail("exists")
    except FileNotFoundError:
        fail("missing")
    except OSError:
        fail("refused")


if __name__ == "__main__":
    main(sys.argv)
