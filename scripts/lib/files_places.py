"""Recent files, network mounts, and removable-disk mount."""

import json
import os
import stat
import subprocess
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(__file__))
import files_safe as safe  # noqa: E402

NET = {
    "cifs", "smb", "smb3", "nfs", "nfs4", "9p", "afs", "ceph", "glusterfs",
    "fuse.sshfs", "fuse.davfs", "davfs", "fuse.rclone",
}
SCHEMES = {"smb", "sftp", "ssh", "ftp", "ftps", "dav", "davs", "nfs", "afp"}


def fail(reason):
    print(reason, file=sys.stderr)
    raise SystemExit(1)


def emit(obj):
    json.dump(obj, sys.stdout)
    sys.stdout.write("\n")


def xbel_path():
    data = os.environ.get("XDG_DATA_HOME") or os.path.join(safe.home_dir(), ".local", "share")
    return os.path.join(data, "recently-used.xbel")


def load_xbel(path):
    if not os.path.isfile(path):
        root = ET.Element("xbel", {"version": "1.0"})
        return ET.ElementTree(root)
    return ET.parse(path)


def href_for(path):
    return "file://" + urllib.parse.quote(path)


def path_of(href):
    if not href.startswith("file://"):
        return ""
    return urllib.parse.unquote(href[7:])


def cmd_recent(_args):
    path = xbel_path()
    rows = []
    if not os.path.isfile(path):
        emit(rows)
        return
    try:
        tree = ET.parse(path)
    except ET.ParseError:
        emit(rows)
        return
    for node in tree.getroot().iter("bookmark"):
        target = path_of(node.get("href") or "")
        if not target.startswith("/") or not os.path.lexists(target):
            continue
        try:
            row = _favorite(target)
        except OSError:
            continue
        child = node.find("title")
        if child is not None and child.text:
            row["name"] = child.text
        rows.append(row)
        if len(rows) >= 40:
            break
    emit(rows)


def cmd_record(args):
    target = safe.clean(args[0])
    if not os.access(target, os.R_OK):
        fail("refused")
    path = xbel_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tree = load_xbel(path)
    root = tree.getroot()
    href = href_for(target)
    for node in list(root.iter("bookmark")):
        if node.get("href") == href:
            root.remove(node)
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    node = ET.Element("bookmark", {"href": href, "added": now, "modified": now, "visited": now})
    title = ET.SubElement(node, "title")
    title.text = os.path.basename(target)
    root.insert(0, node)
    tree.write(path, encoding="unicode", xml_declaration=True)
    emit({"ok": True})


def _rewrite(path, pairs):
    # Longest source wins so a nested folder is not rewritten by its parent.
    best = None
    best_len = -1
    for src, dest in pairs:
        if not src.startswith("/") or len(src) < 2:
            continue
        if path == src or path.startswith(src + "/"):
            if len(src) > best_len:
                best = (src, dest)
                best_len = len(src)
    if best is None:
        return path, False
    src, dest = best
    if not dest:
        return "", True
    if path == src:
        return dest, True
    return dest + path[len(src):], True


def shift_pairs(pairs):
    # Bookmarks that pointed at a moved or deleted file follow that file.
    path = xbel_path()
    if not pairs or not os.path.isfile(path):
        return
    try:
        tree = load_xbel(path)
    except ET.ParseError:
        return
    root = tree.getroot()
    changed = False
    for node in list(root.iter("bookmark")):
        target = path_of(node.get("href") or "")
        mapped, hit = _rewrite(target, pairs)
        if not hit:
            continue
        changed = True
        if not mapped:
            root.remove(node)
            continue
        node.set("href", href_for(mapped))
        title = node.find("title")
        if title is None:
            title = ET.SubElement(node, "title")
        title.text = os.path.basename(mapped) or mapped
    if changed:
        tree.write(path, encoding="unicode", xml_declaration=True)


def _kept(path):
    try:
        return safe.clean(path)
    except safe.Refuse:
        return ""


def shift_drop(sources):
    shift_pairs([(_kept(src), "") for src in sources if _kept(src)])


def shift_move(sources, made):
    pairs = []
    for src, dest in zip(sources, made):
        src, dest = _kept(src), _kept(dest)
        if src and dest:
            pairs.append((src, dest))
    shift_pairs(pairs)


def cmd_clear(_args):
    path = xbel_path()
    if not os.path.isfile(path):
        emit({"ok": True})
        return
    try:
        tree = ET.parse(path)
    except ET.ParseError:
        emit({"ok": True})
        return
    root = tree.getroot()
    for node in list(root.iter("bookmark")):
        root.remove(node)
    tree.write(path, encoding="unicode", xml_declaration=True)
    emit({"ok": True})


def _walk_fs(nodes):
    for node in nodes or []:
        if isinstance(node, dict):
            yield node.get("fstype") or "", node.get("target") or ""
            yield from _walk_fs(node.get("children"))


def _findmnt_pairs():
    proc = subprocess.run(
        ["findmnt", "-J", "-o", "FSTYPE,TARGET"],
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        data = json.loads(proc.stdout or "")
    except json.JSONDecodeError:
        data = None
    if isinstance(data, dict):
        return list(_walk_fs(data.get("filesystems")))
    return []


def _norm_uri(uri):
    parts = urllib.parse.urlsplit(uri)
    path = (parts.path or "").rstrip("/")
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc, path, "", ""))


def _uri(raw):
    text = (raw or "").strip()
    if not text or any(ch in text for ch in "\n\r\x00 "):
        return ""
    if "://" not in text:
        text = "smb://" + text.lstrip("/")
    parts = urllib.parse.urlsplit(text)
    scheme = "sftp" if parts.scheme == "ssh" else parts.scheme
    if scheme not in SCHEMES or not parts.hostname:
        return ""
    return _norm_uri(urllib.parse.urlunsplit((scheme, parts.netloc, parts.path or "", "", "")))


def _uri_label(uri):
    parts = urllib.parse.urlsplit(uri)
    host = parts.hostname or parts.netloc
    share = (parts.path or "").strip("/")
    if parts.username and host:
        host = parts.username + "@" + host
    return share or host or uri


def _gvfs_uri(name):
    if ":" not in name:
        return "", name
    scheme, rest = name.split(":", 1)
    fields = {}
    for bit in rest.split(","):
        if "=" in bit:
            key, value = bit.split("=", 1)
            fields[key] = urllib.parse.unquote(value)
    host = fields.get("server") or fields.get("host") or ""
    share = fields.get("share") or ""
    user = fields.get("user") or ""
    if not host:
        return "", name
    auth = (user + "@" if user else "") + host
    if scheme == "smb-share":
        return _norm_uri("smb://" + host + ("/" + share if share else "")), share or host
    if scheme in {"sftp", "ftp", "nfs", "afp"}:
        return _norm_uri(scheme + "://" + auth + "/"), auth
    if scheme == "dav":
        secure = "davs" if fields.get("ssl") == "true" else "dav"
        return _norm_uri(secure + "://" + auth + "/"), auth
    return "", name


def _retitle(rows, folded, name):
    # The mount point lowercases the share. Keep the name the server sent.
    if not folded or not name:
        return
    for row in rows:
        if _norm_uri(row.get("uri") or "").casefold() != folded:
            continue
        current = str(row.get("name") or "")
        if current.casefold() == name.casefold() and current != name:
            row["name"] = name
        return


def _add_place(rows, seen, path, name, kind, uri):
    # Share names are case-insensitive, so a mounted copy and the
    # announced copy must count as the same place.
    folded = _norm_uri(uri).casefold() if uri else ""
    key = path or folded
    if not key or key in seen or (folded and folded in seen):
        _retitle(rows, folded, name)
        return
    seen.add(key)
    if path:
        seen.add(path)
    if folded:
        seen.add(folded)
    rows.append({"path": path, "name": name or path or uri, "kind": kind, "uri": uri})


def _gvfs_places(rows, seen):
    runtime = os.environ.get("XDG_RUNTIME_DIR") or ""
    if not runtime.startswith("/"):
        return
    folder = os.path.join(runtime, "gvfs")
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return
    for name in names:
        path = os.path.join(folder, name)
        if not os.path.isdir(path):
            continue
        uri, label = _gvfs_uri(name)
        _add_place(rows, seen, path, label, "gvfs", uri)


def _network_places(rows, seen):
    proc = subprocess.run(
        ["gio", "list", "-u", "network://"],
        check=False,
        capture_output=True,
        text=True,
    )
    for line in (proc.stdout or "").splitlines():
        uri = _uri(line.strip())
        if not uri or _norm_uri(uri).casefold() in seen:
            continue
        _add_place(rows, seen, "", _uri_label(uri), "network", uri)


def _ipv4(text):
    bits = (text or "").split(".")
    if len(bits) != 4:
        return False
    try:
        return all(bit.isdigit() and str(int(bit)) == bit and 0 <= int(bit) <= 255 for bit in bits)
    except ValueError:
        return False


def _run(args, timeout):
    try:
        return subprocess.run(args, check=False, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def _disk_shares(host):
    # -g is one share per line. None means the client never ran.
    proc = _run(["smbclient", "-L", host, "-N", "-g"], 3)
    if proc is None:
        return None
    names = []
    for line in (proc.stdout or "").splitlines():
        bits = line.split("|")
        if len(bits) < 2 or bits[0] != "Disk":
            continue
        name = bits[1].strip()
        if not name or name.endswith("$") or "/" in name:
            continue
        names.append(name)
    return names


def _netbios_hosts():
    # The network view's browse misses a server that only answers
    # NetBIOS. A broadcast finds those, including one on this computer.
    proc = _run(["nmblookup", "*"], 2)
    if proc is None:
        return []
    hosts = []
    for line in (proc.stdout or "").splitlines():
        bits = line.split()
        if not bits or not _ipv4(bits[0]) or bits[0] in hosts:
            continue
        hosts.append(bits[0])
    return hosts


def _add_shares(rows, seen, host):
    shares = _disk_shares(host)
    # None means the lookup itself failed, so there is no server to show.
    if shares is None:
        return False
    if not shares:
        _add_place(rows, seen, "", host, "network", _norm_uri("smb://" + host))
        return False
    for share in shares:
        _add_place(rows, seen, "", share, "network", _norm_uri("smb://" + host + "/" + share))
    return True


def _announced_places(rows, seen):
    hosts = _netbios_hosts()
    found = False
    for host in hosts[:8]:
        if _add_shares(rows, seen, host):
            found = True
    if not found:
        _add_shares(rows, seen, "127.0.0.1")


def _places():
    rows = []
    seen = set()
    for kind, target in _findmnt_pairs():
        if kind not in NET or not str(target).startswith("/"):
            continue
        _add_place(rows, seen, target, os.path.basename(target) or target, kind, "")
    _gvfs_places(rows, seen)
    _network_places(rows, seen)
    _announced_places(rows, seen)
    return rows


def cmd_mounts(_args):
    emit(_places())


def cmd_connect(args):
    uri = _uri(args[0] if args else "")
    if not uri:
        fail("refused")
    # No stdin, so a missing password fails instead of waiting forever.
    result = subprocess.run(
        ["gio", "mount", uri],
        check=False,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        fail("refused")
    # The mounted name can differ in case from the address we asked for.
    want = _norm_uri(uri).casefold()
    path = ""
    for row in _places():
        got = _norm_uri(row.get("uri") or "")
        if row.get("path") and got.casefold() == want:
            path = row["path"]
            break
    emit({"path": path, "uri": uri})


def cmd_mount(args):
    name = args[0]
    if not name or "/" in name or not name.replace("-", "").isalnum():
        fail("bad-path")
    dev = "/dev/" + name
    result = subprocess.run(["udisksctl", "mount", "-b", dev], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        fail("refused")
    text = (result.stdout or "") + (result.stderr or "")
    mounted = ""
    if " at " in text:
        mounted = text.split(" at ", 1)[1].strip().rstrip(".")
    emit({"path": mounted})


def _favorite(path):
    st = os.lstat(path)
    link = stat.S_ISLNK(st.st_mode)
    is_dir = stat.S_ISDIR(st.st_mode) or (link and os.path.isdir(path))
    name = os.path.basename(path) or path
    birth = getattr(st, "st_birthtime", None)
    try:
        created = int(birth) if birth else int(st.st_ctime)
    except (TypeError, ValueError):
        created = int(st.st_ctime)
    ext = os.path.splitext(name)[1].lower().lstrip(".")
    if is_dir and not link:
        kind = "dir"
    elif link:
        kind = "link"
    else:
        kind = ext or "file"
    return {
        "name": name,
        "path": path,
        "dir": bool(is_dir and not link),
        "size": -1 if is_dir and not link else int(st.st_size),
        "mtime": int(st.st_mtime),
        "created": created,
        "kind": kind,
        "readable": os.access(path, os.R_OK),
    }


def cmd_present(args):
    rows = []
    for raw in args:
        try:
            path = safe.clean(raw)
        except safe.Refuse:
            continue
        if not os.path.lexists(path):
            continue
        try:
            rows.append(_favorite(path))
        except OSError:
            continue
    emit(rows)


def cmd_dirs(_args):
    home = safe.home_dir()
    names = {"XDG_DOWNLOAD_DIR": "downloads", "XDG_PICTURES_DIR": "pictures", "XDG_VIDEOS_DIR": "videos"}
    found = {key: "" for key in names}
    conf = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"), "user-dirs.dirs")
    if os.path.isfile(conf):
        with open(conf, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if not line.startswith("XDG_") or "=" not in line:
                    continue
                key, value = line.strip().split("=", 1)
                value = value.strip().strip('"').replace("$HOME", home)
                if key in names and value.startswith("/"):
                    found[key] = value
    rows = [{"id": "home", "path": home}]
    fallback = {"downloads": "Downloads", "pictures": "Pictures", "videos": "Videos"}
    for key, ident in names.items():
        path = found[key] or os.path.join(home, fallback[ident])
        if os.path.isdir(path):
            rows.append({"id": ident, "path": path})
    emit(rows)


def main(argv):
    commands = {
        "recent": cmd_recent,
        "record": cmd_record,
        "clear": cmd_clear,
        "mounts": cmd_mounts,
        "mount": cmd_mount,
        "connect": cmd_connect,
        "dirs": cmd_dirs,
        "present": cmd_present,
    }
    if len(argv) < 2 or argv[1] not in commands:
        fail("usage")
    try:
        commands[argv[1]](argv[2:])
    except safe.Refuse as exc:
        fail(exc.reason)
    except OSError:
        fail("refused")


if __name__ == "__main__":
    main(sys.argv)
