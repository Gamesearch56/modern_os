"""Replace a file's bytes without ever leaving it half written.

write() picks the method: a temp file in the same folder, fsync, rename,
fsync the folder (mode, group, and xattrs copied over); or, for a file
someone else owns, a hard link, or a folder we cannot write, rewriting
the inode itself so owner, links, and ACLs stay put.
"""

import os
import stat
import tempfile


def _copy_meta(fd, path, raw):
    os.fchmod(fd, stat.S_IMODE(raw.st_mode))
    try:
        os.fchown(fd, -1, raw.st_gid)
    except OSError:
        pass
    try:
        for name in os.listxattr(path):
            try:
                os.setxattr(fd, name, os.getxattr(path, name))
            except OSError:
                pass
    except OSError:
        pass


def write_atomic(target, data, raw):
    folder = os.path.dirname(target) or "/"
    fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(target) + ".", suffix=".tmp", dir=folder)
    try:
        if raw is not None:
            _copy_meta(fd, target, raw)
        else:
            mask = os.umask(0)
            os.umask(mask)
            os.fchmod(fd, 0o666 & ~mask)
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, target)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    dfd = os.open(folder, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        os.fsync(dfd)
    finally:
        os.close(dfd)


def write_in_place(target, data):
    fd = os.open(target, os.O_WRONLY | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC)
    with os.fdopen(fd, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def write(target, data, raw):
    """target is a real path; raw is its os.stat() result, or None if new."""
    folder = os.path.dirname(target) or "/"
    if raw is not None and (raw.st_uid != os.getuid() or raw.st_nlink > 1
                            or not os.access(folder, os.W_OK)):
        write_in_place(target, data)
    else:
        write_atomic(target, data, raw)
