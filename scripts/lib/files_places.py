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

NET = {"cifs", "nfs", "nfs4", "fuse.sshfs", "fuse.davfs", "davfs"}


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


def cmd_mounts(_args):
    proc = subprocess.run(
        ["findmnt", "-n", "-o", "FSTYPE,TARGET"],
        check=False,
        capture_output=True,
        text=True,
    )
    rows = []
    for line in (proc.stdout or "").splitlines():
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        kind, target = parts
        if kind not in NET or not target.startswith("/"):
            continue
        rows.append({"path": target, "name": os.path.basename(target) or target, "kind": kind})
    emit(rows)


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
