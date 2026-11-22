"""Path checks for the file manager. lstat before a change. Reject '..'."""

import ctypes
import errno
import os
import pwd
import stat

PROTECTED = (
    "/",
    "/boot",
    "/efi",
    "/usr",
    "/bin",
    "/sbin",
    "/lib",
    "/lib64",
    "/etc",
    "/proc",
    "/sys",
    "/dev",
    "/run",
    "/var",
    "/opt",
    "/root",
)


class Refuse(Exception):
    def __init__(self, reason="refused"):
        super().__init__(reason)
        self.reason = reason


_home = ""
_user = ""


def home_dir():
    # A folder listing asks for this once per row. Resolve it once.
    global _home
    if not _home:
        _home = os.path.realpath(os.environ.get("HOME") or pwd.getpwuid(os.getuid()).pw_dir)
    return _home


def user_name():
    global _user
    if not _user:
        _user = pwd.getpwuid(os.getuid()).pw_name
    return _user


def clean(path):
    raw = str(path or "")
    if not raw or "\0" in raw or not raw.startswith("/"):
        raise Refuse("bad-path")
    parts = []
    for part in raw.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            raise Refuse("bad-path")
        parts.append(part)
    return "/" + "/".join(parts) if parts else "/"


def media_root(user=None):
    return "/run/media/" + (user or user_name())


_roots_for = {}


def _checkout_pointer(home):
    # Same order as scripts/lib/repo-path.sh. The session exports
    # MODERN_REPO, so a file manager started from it sees that path.
    env = os.environ.get("MODERN_REPO", "").strip()
    if env:
        return env
    cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
    pointer = os.path.join(cfg, "modern", "repo")
    try:
        with open(pointer, encoding="utf-8") as fh:
            return fh.readline().strip()
    except OSError:
        return ""


def install_roots(home=None):
    # The installed checkout sits in the home folder, so Files would
    # otherwise rename or delete the desktop the session runs from.
    # A working tree with another name stays editable.
    home = home or home_dir()
    cached = _roots_for.get(home)
    if cached is not None:
        return cached
    roots = []

    def add(raw):
        if not raw:
            return
        if not str(raw).startswith("/"):
            raw = os.path.join(home, raw)
        try:
            path = clean(raw)
        except Refuse:
            return
        if not path.startswith(home + "/") or os.path.basename(path) != "modern_os":
            return
        if path not in roots:
            roots.append(path)

    add(os.path.join(home, "modern_os"))
    add(_checkout_pointer(home))
    _roots_for[home] = roots
    return roots


def protected(path, home=None, user=None):
    path = clean(path)
    home = home or home_dir()
    user = user or user_name()
    media = media_root(user)
    if path == media or path.startswith(media + "/"):
        return False
    if path == home:
        return True
    for root in PROTECTED:
        if path == root or (root != "/" and path.startswith(root + "/")) or (root == "/" and False):
            return True
    if path == "/":
        return True
    for root in install_roots(home):
        if path == root or path.startswith(root + "/"):
            return True
    return False


def under(path, root):
    path = clean(path)
    root = clean(root)
    return path.startswith(root + "/")


def owner_offered(path, home=None, user=None):
    path = clean(path)
    home = home or home_dir()
    user = user or user_name()
    if protected(path, home, user):
        return False
    for root in (home, "/tmp", "/mnt", "/media", media_root(user)):
        if under(path, root):
            return True
    return False


def parent_of(path):
    path = clean(path)
    parent = os.path.dirname(path)
    return parent if parent else "/"


def can_list(path):
    path = clean(path)
    return os.path.isdir(path) and os.access(path, os.R_OK | os.X_OK)


def can_read(path):
    path = clean(path)
    return os.access(path, os.R_OK)


def can_edit_parent(path):
    # The home directory node is protected, but files inside it are not.
    # Writability is the parent's mode, not whether that parent is protected.
    return os.access(parent_of(clean(path)), os.W_OK | os.X_OK)


def ensure_mutable(path):
    path = clean(path)
    if protected(path):
        raise Refuse("protected")
    # A symlink under the home directory must not redirect a write into
    # a protected directory. The final name is not resolved, so deleting
    # a symlink still removes the link rather than its target.
    parent = parent_of(path)
    real = os.path.realpath(parent)
    home = home_dir()
    if protected(real) and real != home:
        raise Refuse("protected")
    if not os.access(real, os.W_OK | os.X_OK):
        raise Refuse("refused")
    return path


def leaf_name(name):
    text = str(name or "")
    if (
        not text
        or text in (".", "..")
        or "/" in text
        or "\0" in text
        or "\n" in text
        or "\r" in text
        or len(os.fsencode(text)) > 255
    ):
        raise Refuse("bad-path")
    return text


def account_name(name):
    text = leaf_name(name)
    if text.startswith("-"):
        raise Refuse("bad-path")
    return text


def open_dir(path, write):
    path = clean(path)
    real = os.path.realpath(path)
    home = home_dir()
    if write and ((protected(path) and path != home) or (protected(real) and real != home)):
        raise Refuse("protected")
    if not os.path.isdir(real):
        raise FileNotFoundError(path)
    need = os.W_OK | os.X_OK if write else os.R_OK | os.X_OK
    if not os.access(real, need):
        raise Refuse("refused")
    try:
        return os.open(real, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError as exc:
        raise Refuse("refused") from exc


def open_parent(path, write=True):
    path = ensure_mutable(path) if write else clean(path)
    parent = parent_of(path)
    name = leaf_name(os.path.basename(path))
    return open_dir(parent, write), name


_libc = ctypes.CDLL(None, use_errno=True)
_libc.renameat2.argtypes = [
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_uint,
]
_libc.renameat2.restype = ctypes.c_int


def rename_noreplace(src_dir, src, dst_dir, dst):
    # RENAME_NOREPLACE fails if the new name exists. A plain rename would
    # destroy that file, and a check-then-rename loses the race.
    rc = _libc.renameat2(
        ctypes.c_int(src_dir),
        os.fsencode(src),
        ctypes.c_int(dst_dir),
        os.fsencode(dst),
        ctypes.c_uint(1),
    )
    if rc == 0:
        return
    err = ctypes.get_errno()
    if err == errno.EEXIST:
        raise FileExistsError(dst)
    if err == errno.EXDEV:
        raise OSError(err, "cross-device")
    raise OSError(err, os.strerror(err), dst)


def rename_leaf(path, new_name):
    new_name = leaf_name(new_name)
    src_dir, src = open_parent(path)
    try:
        if src == new_name:
            return path
        rename_noreplace(src_dir, src, src_dir, new_name)
    finally:
        os.close(src_dir)
    return os.path.join(parent_of(path), new_name)


def _taken(dir_fd, name):
    try:
        os.lstat(name, dir_fd=dir_fd)
    except FileNotFoundError:
        return False
    return True


def _duplicate(name, n):
    # The marker stays in front. A shortened row still shows this is the copy.
    return f"({n}) {name}"


def _free_name(dir_fd, name, occupy):
    # Pick a free name before writing. The file already in the folder is
    # never opened, so a paste beside itself cannot replace it.
    for n in range(0, 1000):
        cand = name if n == 0 else _duplicate(name, n + 1)
        if _taken(dir_fd, cand) or len(os.fsencode(cand)) > 255:
            continue
        try:
            occupy(cand)
            return cand
        except FileExistsError:
            continue
    raise FileExistsError(name)


def create_dir(parent, name):
    name = leaf_name(name)
    dfd, leaf = open_parent(os.path.join(parent, name))
    try:
        os.mkdir(leaf, 0o777, dir_fd=dfd)
    finally:
        os.close(dfd)
    return os.path.join(parent, name)


def create_file(parent, name):
    name = leaf_name(name)
    dfd, leaf = open_parent(os.path.join(parent, name))
    try:
        fd = os.open(
            leaf,
            os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
            0o644,
            dir_fd=dfd,
        )
        os.close(fd)
    finally:
        os.close(dfd)
    return os.path.join(parent, name)


def is_link(path):
    return stat.S_ISLNK(os.lstat(path).st_mode)


def _inside(dest_dir, src):
    try:
        src_real = os.path.realpath(src)
        dest_real = os.path.realpath(dest_dir)
    except OSError:
        return False
    return dest_real == src_real or dest_real.startswith(src_real + os.sep)


def _copy_reg(src_dir, src, dst_dir, dst, st):
    sfd = os.open(src, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=src_dir)
    try:
        dfd = os.open(
            dst,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
            0o644,
            dir_fd=dst_dir,
        )
        try:
            copied = False
            try:
                while True:
                    n = os.copy_file_range(sfd, dfd, 8 * 1024 * 1024)
                    if not n:
                        break
                    copied = True
            except OSError:
                if copied:
                    raise
                while True:
                    buf = os.read(sfd, 1024 * 1024)
                    if not buf:
                        break
                    os.write(dfd, buf)
            os.fchmod(dfd, stat.S_IMODE(st.st_mode) & 0o777)
            os.utime(dfd, ns=(st.st_atime_ns, st.st_mtime_ns))
        finally:
            os.close(dfd)
    finally:
        os.close(sfd)


def _copy_name(src_dir, name, dst_dir, dest_name):
    st = os.lstat(name, dir_fd=src_dir)
    if stat.S_ISLNK(st.st_mode):
        os.symlink(os.readlink(name, dir_fd=src_dir), dest_name, dir_fd=dst_dir)
        return
    if stat.S_ISDIR(st.st_mode):
        os.mkdir(dest_name, 0o777, dir_fd=dst_dir)
        sfd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=src_dir)
        dfd = os.open(dest_name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=dst_dir)
        try:
            with os.scandir(sfd) as scan:
                kids = [item.name for item in scan]
            for child in kids:
                _copy_name(sfd, child, dfd, child)
        finally:
            os.close(sfd)
            os.close(dfd)
        return
    if not stat.S_ISREG(st.st_mode):
        raise Refuse("refused")
    _copy_reg(src_dir, name, dst_dir, dest_name, st)


def _as_dir(dest):
    # Paste can be aimed at the file that was copied. Land beside it.
    dest = clean(dest)
    if os.path.isdir(dest):
        return dest
    if os.path.lexists(dest):
        return parent_of(dest)
    return dest


def landing_dir(dest):
    return _as_dir(dest)


def copy_named(src, dest_dir, leaf):
    # The name was chosen in the dialog. Do not invent another "(2)".
    src = clean(src)
    dest_dir = _as_dir(dest_dir)
    leaf = leaf_name(leaf)
    if _inside(dest_dir, src):
        raise Refuse("refused")
    if not os.path.lexists(src):
        raise FileNotFoundError(src)
    target = os.path.join(dest_dir, leaf)
    if os.path.lexists(target):
        raise FileExistsError(target)
    src_dir, src_name = open_parent(src, write=False)
    dst_dir, dst_name = open_parent(target)
    try:
        _copy_name(src_dir, src_name, dst_dir, dst_name)
    finally:
        os.close(src_dir)
        os.close(dst_dir)
    return target


def copy_into(src, dest_dir):
    src = clean(src)
    dest_dir = _as_dir(dest_dir)
    if _inside(dest_dir, src):
        raise Refuse("refused")
    if not os.path.lexists(src):
        raise FileNotFoundError(src)
    src_dir, src_name = open_parent(src, write=False)
    dst_dir = open_dir(dest_dir, True)
    try:
        # A paste keeps both copies. The next free name is used so the
        # file already in the folder is never replaced.
        made = _free_name(dst_dir, src_name, lambda cand: _copy_name(src_dir, src_name, dst_dir, cand))
    finally:
        os.close(src_dir)
        os.close(dst_dir)
    return os.path.join(dest_dir, made)


def _remove_dir(parent_fd, name):
    fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent_fd)
    try:
        with os.scandir(fd) as scan:
            kids = [item.name for item in scan]
        for child in kids:
            st = os.lstat(child, dir_fd=fd)
            if stat.S_ISDIR(st.st_mode) and not stat.S_ISLNK(st.st_mode):
                _remove_dir(fd, child)
            else:
                os.unlink(child, dir_fd=fd)
    finally:
        os.close(fd)
    os.rmdir(name, dir_fd=parent_fd)


def remove_path(path):
    dfd, name = open_parent(path)
    try:
        st = os.lstat(name, dir_fd=dfd)
        if stat.S_ISDIR(st.st_mode) and not stat.S_ISLNK(st.st_mode):
            _remove_dir(dfd, name)
        else:
            os.unlink(name, dir_fd=dfd)
    finally:
        os.close(dfd)


def move_exact(src, dest):
    # Undo puts the file back at its old path. A free-name move would
    # invent "(2)" and the next redo would not find the original.
    src = clean(src)
    dest = ensure_mutable(clean(dest))
    if not os.path.lexists(src):
        raise FileNotFoundError(src)
    try:
        if os.path.realpath(src) == os.path.realpath(dest):
            return dest
    except OSError:
        pass
    if os.path.lexists(dest):
        raise FileExistsError(dest)
    parent = parent_of(dest)
    if _inside(parent, src):
        raise Refuse("refused")
    src_dir, src_name = open_parent(src)
    dst_dir, dst_name = open_parent(dest)
    try:
        try:
            rename_noreplace(src_dir, src_name, dst_dir, dst_name)
            return dest
        except OSError as exc:
            if exc.errno != errno.EXDEV:
                raise
    finally:
        os.close(src_dir)
        os.close(dst_dir)
    src_dir, src_name = open_parent(src, write=False)
    dst_dir, dst_name = open_parent(dest)
    try:
        _copy_name(src_dir, src_name, dst_dir, dst_name)
    finally:
        os.close(src_dir)
        os.close(dst_dir)
    remove_path(src)
    return dest


def move_into(src, dest_dir):
    src = clean(src)
    dest_dir = clean(dest_dir)
    if _inside(dest_dir, src):
        raise Refuse("refused")
    src_dir, src_name = open_parent(src)
    dst_dir = open_dir(dest_dir, True)
    try:
        try:
            made = _free_name(
                dst_dir,
                src_name,
                lambda cand: rename_noreplace(src_dir, src_name, dst_dir, cand),
            )
            return os.path.join(dest_dir, made)
        except OSError as exc:
            if exc.errno != errno.EXDEV:
                raise
        made = copy_into(src, dest_dir)
        remove_path(src)
        return made
    finally:
        os.close(src_dir)
        os.close(dst_dir)


def chmod_nofollow(path, mode):
    dfd, name = open_parent(path)
    try:
        st = os.lstat(name, dir_fd=dfd)
        if stat.S_ISLNK(st.st_mode) or st.st_uid != os.getuid():
            raise Refuse("refused")
        flags = os.O_NOFOLLOW | os.O_CLOEXEC
        if stat.S_ISDIR(st.st_mode):
            flags |= os.O_RDONLY | os.O_DIRECTORY
        else:
            flags |= os.O_RDONLY
        try:
            fd = os.open(name, flags, dir_fd=dfd)
        except PermissionError:
            fd = os.open(name, os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=dfd)
        try:
            os.fchmod(fd, (st.st_mode & 0o7000) | mode)
        finally:
            os.close(fd)
    finally:
        os.close(dfd)


def chgrp_nofollow(path, gid):
    dfd, name = open_parent(path)
    try:
        st = os.lstat(name, dir_fd=dfd)
        if st.st_uid != os.getuid():
            raise Refuse("refused")
        os.chown(name, -1, gid, dir_fd=dfd, follow_symlinks=False)
    finally:
        os.close(dfd)


def owned(path):
    return os.lstat(path).st_uid == os.getuid()
