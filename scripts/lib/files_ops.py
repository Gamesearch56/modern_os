"""List and change files. Every path is checked before the call."""

import grp
import json
import os
import pwd
import stat
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import files_places as places  # noqa: E402
import files_safe as safe  # noqa: E402
import files_size_cache as size_cache  # noqa: E402


def fail(reason):
    print(reason, file=sys.stderr)
    raise SystemExit(1)


def emit(obj):
    json.dump(obj, sys.stdout)
    sys.stdout.write("\n")


def entry(path):
    st = os.lstat(path)
    link = stat.S_ISLNK(st.st_mode)
    is_dir = stat.S_ISDIR(st.st_mode) or (link and os.path.isdir(path))
    return {
        "name": os.path.basename(path) or path,
        "path": path,
        "dir": bool(is_dir and not link),
        "link": bool(link),
        # Folder totals walk every nested file. The list stays at -1 so
        # the window can paint; `sizes` fills the real total afterward.
        "size": -1 if is_dir and not link else int(st.st_size),
        "mtime": int(st.st_mtime),
        "created": created_of(st),
        "kind": kind_of(path, is_dir, link),
        "readable": os.access(path, os.R_OK),
        "editable": safe.can_edit_parent(path) and not safe.protected(path),
    }


def created_of(st):
    # Birth time is real creation. Filesystems that omit it report 0,
    # and the status-change time is the closest stamp we can show.
    birth = getattr(st, "st_birthtime", None)
    try:
        if birth:
            return int(birth)
    except (TypeError, ValueError):
        pass
    return int(st.st_ctime)


def kind_of(path, is_dir, link):
    if is_dir and not link:
        return "dir"
    if link:
        return "link"
    ext = os.path.splitext(os.path.basename(path))[1].lower().lstrip(".")
    return ext or "file"


def sort_key(item, kind):
    if kind in ("updated", "modified"):
        return item["mtime"]
    if kind == "created":
        return item["created"]
    if kind == "size":
        return item["size"]
    if kind == "type":
        ext = os.path.splitext(item["name"])[1].lower()
        return ext or item["name"].casefold()
    return item["name"].casefold()


def cmd_list(args):
    path = safe.clean(args[0])
    hidden = args[1] == "1"
    kind = args[2] if len(args) > 2 else "name"
    desc = args[3] == "1" if len(args) > 3 else True
    folders = args[4] != "0" if len(args) > 4 else True
    if kind not in ("name", "modified", "updated", "created", "size", "type"):
        fail("bad-sort")
    if not os.path.isdir(path):
        fail("missing")
    if not safe.can_list(path):
        fail("denied")
    rows = []
    with os.scandir(path) as it:
        for item in it:
            if not hidden and item.name.startswith("."):
                continue
            try:
                rows.append(entry(item.path))
            except OSError:
                continue
    def order(group):
        group.sort(key=lambda row: sort_key(row, kind), reverse=desc)
        return group
    if folders:
        dirs = order([row for row in rows if row["dir"]])
        files = order([row for row in rows if not row["dir"]])
        rows = dirs + files
    else:
        rows = order(rows)
    emit(rows)


def cmd_sizes(args):
    path = safe.clean(args[0])
    hidden = args[1] == "1" if len(args) > 1 else False
    if not os.path.isdir(path):
        fail("missing")
    if not safe.can_list(path):
        fail("denied")
    with os.scandir(path) as it:
        for item in it:
            if not hidden and item.name.startswith("."):
                continue
            try:
                st = item.stat(follow_symlinks=False)
            except OSError:
                continue
            if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
                continue
            if not os.access(item.path, os.R_OK | os.X_OK):
                total = -1
            else:
                total = size_cache.total(item.path, st)
            emit({"path": item.path, "size": total})
            sys.stdout.flush()


def cmd_stat(args):
    path = safe.clean(args[0])
    try:
        st = os.lstat(path)
    except OSError:
        fail("missing")
    mode = stat.S_IMODE(st.st_mode)
    bits = []
    for flag in (0o400, 0o200, 0o100, 0o040, 0o020, 0o010, 0o004, 0o002, 0o001):
        bits.append("1" if mode & flag else "0")
    try:
        owner = pwd.getpwuid(st.st_uid).pw_name
    except KeyError:
        owner = str(st.st_uid)
    try:
        group = grp.getgrgid(st.st_gid).gr_name
    except KeyError:
        group = str(st.st_gid)
    groups = []
    for gid in set(os.getgroups()) | {os.getgid()}:
        try:
            groups.append(grp.getgrgid(gid).gr_name)
        except KeyError:
            continue
    emit({
        "path": path,
        "name": os.path.basename(path) or path,
        "dir": stat.S_ISDIR(st.st_mode),
        "link": stat.S_ISLNK(st.st_mode),
        "size": int(st.st_size),
        "mtime": int(st.st_mtime),
        "bits": "".join(bits),
        "setuid": bool(st.st_mode & stat.S_ISUID),
        "setgid": bool(st.st_mode & stat.S_ISGID),
        "sticky": bool(st.st_mode & stat.S_ISVTX),
        "owner": owner,
        "group": group,
        "uid": st.st_uid,
        "canRead": os.access(path, os.R_OK),
        "canChmod": safe.owned(path) and not safe.protected(path) and not stat.S_ISLNK(st.st_mode),
        "canChgrp": safe.owned(path) and not safe.protected(path),
        "canChown": safe.owner_offered(path),
        "groups": groups,
        "editable": safe.can_edit_parent(path) and not safe.protected(path),
    })


def parse_bits(text):
    text = str(text or "")
    if len(text) != 9 or any(ch not in "01" for ch in text):
        fail("bad-mode")
    mode = 0
    for i, ch in enumerate(text):
        if ch == "1":
            mode |= 1 << (8 - i)
    return mode


def _allowed_groups():
    allowed = set()
    for gid in set(os.getgroups()) | {os.getgid()}:
        try:
            allowed.add(grp.getgrgid(gid).gr_name)
        except KeyError:
            continue
    return allowed


def _chown(path, user):
    path = safe.ensure_mutable(safe.clean(path))
    user = safe.account_name(user)
    if not safe.owner_offered(path):
        fail("refused")
    try:
        pwd.getpwnam(user)
    except KeyError:
        fail("refused")
    # "--" keeps a path from being read as a chown flag.
    result = subprocess.run(
        ["pkexec", "chown", "--no-dereference", user, "--", path],
        check=False,
    )
    if result.returncode != 0:
        fail("refused")


def _all(paths, fn, after=None):
    if not paths:
        fail("usage")
    reason = None
    made = []
    for path in paths:
        try:
            result = fn(path)
        except safe.Refuse as exc:
            reason = reason or exc.reason
        except FileExistsError:
            reason = reason or "exists"
        except FileNotFoundError:
            reason = reason or "missing"
        except OSError:
            reason = reason or "refused"
        else:
            landed = result if isinstance(result, str) and result else ""
            if landed:
                made.append(landed)
            if after:
                after(path, landed)
    if reason:
        fail(reason)
    emit({"ok": True, "paths": made})


def cmd_chmod(args):
    safe.chmod_nofollow(safe.clean(args[0]), parse_bits(args[1]))
    emit({"ok": True})


def cmd_chgrp(args):
    path = safe.clean(args[0])
    group = safe.account_name(args[1])
    if group not in _allowed_groups():
        fail("refused")
    safe.chgrp_nofollow(path, grp.getgrnam(group).gr_gid)
    emit({"ok": True})


def cmd_chown(args):
    _chown(args[0], args[1])
    emit({"ok": True})


def cmd_mkdir(args):
    made = safe.create_dir(args[0], args[1])
    size_cache.forget(made)
    emit({"path": made})


def cmd_touch(args):
    made = safe.create_file(args[0], args[1])
    size_cache.forget(made)
    emit({"path": made})


def cmd_rename(args):
    old = safe.clean(args[0])
    made = safe.rename_leaf(args[0], args[1])
    size_cache.forget(old)
    size_cache.forget(made)
    places.shift_move([old], [made])
    emit({"path": made})


def cmd_edit(args):
    if len(args) < 1:
        fail("usage")
    path = args[0]
    name = mode = owner = None
    index = 1
    while index < len(args):
        flag = args[index]
        if index + 1 >= len(args) or flag not in ("--name", "--mode", "--owner"):
            fail("usage")
        value = args[index + 1]
        if flag == "--name":
            name = value
        elif flag == "--mode":
            mode = value
        else:
            owner = value
        index += 2
    parsed = parse_bits(mode) if mode is not None else None
    if name is not None:
        safe.leaf_name(name)
    if owner is not None:
        safe.account_name(owner)
    old = safe.clean(path)
    if parsed is not None:
        safe.chmod_nofollow(old, parsed)
    if owner is not None:
        _chown(path, owner)
    if name is not None and os.path.basename(old) != name:
        path = safe.rename_leaf(path, name)
        places.shift_move([old], [path])
    else:
        path = old
    size_cache.forget(old)
    size_cache.forget(path)
    emit({"path": path, "ok": True})


def _drop_sizes(paths):
    for path in paths:
        try:
            size_cache.forget(safe.clean(path))
        except safe.Refuse:
            continue


def cmd_copy(args):
    if len(args) < 2:
        fail("usage")
    dest = args[0]
    _drop_sizes([dest])
    _all(args[1:], lambda src: safe.copy_into(src, dest))


def cmd_move(args):
    if len(args) < 2:
        fail("usage")
    dest = args[0]
    _drop_sizes([dest] + args[1:])
    _all(args[1:], lambda src: safe.move_into(src, dest), lambda src, landed: places.shift_move([src], [landed]) if landed else None)


def cmd_delete(args):
    _drop_sizes(args)
    _all(args, safe.remove_path, lambda src, _landed: places.shift_drop([src]))


COMMANDS = {
    "list": cmd_list,
    "sizes": cmd_sizes,
    "stat": cmd_stat,
    "chmod": cmd_chmod,
    "chgrp": cmd_chgrp,
    "chown": cmd_chown,
    "mkdir": cmd_mkdir,
    "touch": cmd_touch,
    "rename": cmd_rename,
    "edit": cmd_edit,
    "copy": cmd_copy,
    "move": cmd_move,
    "delete": cmd_delete,
}


def main(argv):
    if len(argv) < 2 or argv[1] not in COMMANDS:
        fail("usage")
    try:
        COMMANDS[argv[1]](argv[2:])
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
