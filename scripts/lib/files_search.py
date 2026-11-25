"""Name and content search. Arguments stay a list; nothing is passed to a shell."""

import json
import os
import re
import stat
import subprocess
import sys
import time
from collections import deque

sys.path.insert(0, os.path.dirname(__file__))
import files_safe as safe  # noqa: E402
import files_size_cache as size_cache  # noqa: E402

CAP = 200
# Name search keeps the best folders and files, not the first hits it walks.
FOLDER_KEEP = 24
FILE_KEEP = 24
DIR_CAP = 100000
SKIP = ("/proc", "/sys", "/dev", "/run")
# Dependency and VCS caches bury a real match. Game libraries stay.
SKIP_DOWN = frozenset({
    "node_modules", ".git", ".hg", ".svn", "__pycache__",
    ".cache", "Cache", "GPUCache", "Code Cache",
    "shadercache", "downloading", "depotcache", "appcache",
})
# Walk these before unrelated trees so a Steam or Wine install is reached
# before the rest of the home directory is listed.
PREFER = frozenset({
    ".local", "share", "steam", "steamapps", "compatdata", "games",
    "pfx", "drive_c", "bottles", "lutris", "wine", "prefixes",
})
# Addon and cache copies of a name should sit below the install folder.
NOISE = frozenset({
    "addons", "interface", "cache", "gpucache", "code cache",
    "shadercache", "node_modules",
})
_WORD = re.compile(r"[^0-9a-z]+")


def fail(reason):
    print(reason, file=sys.stderr)
    raise SystemExit(1)


def emit_line(obj):
    # One object per line, flushed, so the shell can show hits before
    # the rest of the tree has been walked.
    json.dump(obj, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    sys.stdout.flush()


def flag(argv, name, default=""):
    if name in argv:
        i = argv.index(name)
        if i + 1 >= len(argv):
            fail("usage")
        return argv[i + 1]
    return default


def root_for(scope, folder):
    if scope == "home":
        return safe.home_dir()
    if scope == "computer":
        return "/"
    if scope == "folder":
        path = safe.clean(folder)
        if not safe.can_list(path):
            fail("refused")
        return path
    fail("usage")


def skipped(scope, path):
    if scope != "computer":
        return False
    return path in SKIP or any(path.startswith(item + "/") for item in SKIP)


def words_of(text):
    return [part for part in _WORD.split(text.casefold()) if part]


def acronym_hit(words, token):
    # "wow" is the initials of "World of Warcraft", including the short "of".
    count = len(words)
    for start in range(count):
        acc = ""
        for index in range(start, count):
            acc += words[index][:1]
            if acc == token:
                return True
            if len(acc) >= len(token):
                break
    return False


def token_score(token, folded, words):
    if any(word == token for word in words):
        return 80
    if len(token) < 2:
        return 0
    if any(word.startswith(token) for word in words):
        return 55
    if acronym_hit(words, token):
        return 70
    if token in folded:
        return 15
    return 0


def bare(text):
    return _WORD.sub("", text.casefold())


def score_name(name, query):
    # Every word of the query has to match. One shared substring is not enough:
    # "wow forever game" must not be a pile of unrelated "game" files.
    # "_forever_" is the same name as "Forever" once the separators are gone.
    folded_query = query.casefold().strip()
    tokens = words_of(folded_query)
    if not tokens:
        return 0
    folded = name.casefold()
    if folded == folded_query or (bare(name) and bare(name) == bare(folded_query)):
        return 1000
    words = words_of(name)
    total = 400 if folded.startswith(folded_query) else 0
    for token in tokens:
        hit = token_score(token, folded, words)
        if hit <= 0:
            return 0
        total += hit
    return total


def buried(path):
    parts = [part.casefold() for part in path.split("/")[:-1] if part]
    return any(part in NOISE for part in parts)


def created_of(st):
    birth = getattr(st, "st_birthtime", None)
    try:
        if birth:
            return int(birth)
    except (TypeError, ValueError):
        pass
    return int(st.st_ctime)


def hit_row(path, name, is_dir, st, score, line=""):
    # Same stamps the folder list paints. Folder totals reuse a saved
    # measure when one exists; a cold hit stays at -1 so the walk stays
    # short.
    if is_dir:
        size = size_cache.read(path, st.st_mtime_ns)
        if size is None:
            size = -1
    else:
        size = int(st.st_size)
    kind = "dir" if is_dir else (os.path.splitext(name)[1].lower().lstrip(".") or "file")
    return {
        "path": path,
        "name": name,
        "dir": is_dir,
        "score": score,
        "line": line,
        "size": size,
        "mtime": int(st.st_mtime),
        "created": created_of(st),
        "kind": kind,
        "readable": True,
        "link": False,
    }


def search_roots(scope, folder):
    if scope == "computer":
        return ["/"]
    if scope == "home":
        return [safe.home_dir()]
    return [root_for("folder", folder)]


def cmd_names(scope, folder, query, hidden, near=""):
    # The best folders and files are kept for the whole walk. A hidden
    # parent such as .local is entered so a Steam install can be found,
    # and a matching install directory is listed before unrelated trees.
    show_hidden = hidden == "1"
    folders = {}
    files = {}
    queue = deque()
    seen = set()
    dir_visits = 0
    last = 0.0
    try:
        near_path = safe.clean(near) if near else ""
    except safe.Refuse:
        near_path = ""
    for root in search_roots(scope, folder):
        queue.append((root, 0))

    def publish(force=False):
        nonlocal last
        now = time.monotonic()
        if not force and last and now - last < 0.15:
            return
        last = now
        rows = [item for _score, item in folders.values()]
        rows.extend(item for _score, item in files.values())
        rows.sort(key=lambda row: (-row["score"], row["name"].casefold()))
        emit_line({"q": query, "replace": rows})

    def enqueue(path, depth):
        name = os.path.basename(path).casefold()
        if name in PREFER or score_name(os.path.basename(path), query) > 0:
            queue.appendleft((path, depth))
        else:
            queue.append((path, depth))

    def consider(pool, limit, score, path, name, is_dir, st, depth):
        score -= min(depth, 40)
        if is_dir:
            score += 25
        if buried(path):
            score -= 450
        if near_path and (path == near_path or path.startswith(near_path + os.sep)):
            score += 30
        if score <= 0:
            return
        prev = pool.get(path)
        if prev is not None and prev[0] >= score:
            return
        pool[path] = (score, hit_row(path, name, is_dir, st, score))
        if len(pool) <= limit:
            publish()
            return
        worst = min(pool, key=lambda key: pool[key][0])
        del pool[worst]
        publish()

    while queue and dir_visits < DIR_CAP:
        current, depth = queue.popleft()
        if current in seen or skipped(scope, current):
            continue
        seen.add(current)
        dir_visits += 1
        try:
            scan = os.scandir(current)
        except OSError:
            continue
        with scan:
            for item in scan:
                path = item.path
                if skipped(scope, path):
                    continue
                try:
                    st = item.stat(follow_symlinks=False)
                except OSError:
                    continue
                mode = st.st_mode
                is_link = stat.S_ISLNK(mode)
                is_dir = stat.S_ISDIR(mode) and not is_link
                hidden_name = item.name.startswith(".")
                if hidden_name and not show_hidden:
                    if is_dir and item.name not in SKIP_DOWN:
                        enqueue(path, depth + 1)
                    continue
                got = score_name(item.name, query)
                if got > 0 and os.access(path, os.R_OK):
                    pool = folders if is_dir else files
                    limit = FOLDER_KEEP if is_dir else FILE_KEEP
                    consider(pool, limit, got, path, item.name, is_dir, st, depth)
                if is_dir and item.name not in SKIP_DOWN:
                    enqueue(path, depth + 1)
    # The last paint can afford the folder totals. Earlier replaces stay
    # light so hits appear while the tree is still walking.
    for path, (score, row) in list(folders.items()):
        if int(row.get("size", -1)) >= 0:
            continue
        try:
            st = os.lstat(path)
        except OSError:
            continue
        filled = dict(row)
        filled["size"] = size_cache.total(path, st)
        folders[path] = (score, filled)
    publish(True)


def cmd_contents(scope, folder, query, hidden):
    root = root_for(scope, folder)
    cmd = ["grep", "-R", "-n", "-I", "--binary-files=without-match"]
    if hidden != "1":
        cmd.append("--exclude-dir=.*")
    if scope == "computer":
        for path in SKIP:
            cmd.append("--exclude-dir=" + os.path.basename(path))
    cmd.extend(["-e", query, "--", root])
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    found = 0
    try:
        for line in proc.stdout:
            path, sep, rest = line.rstrip("\n").partition(":")
            if sep != ":" or not path.startswith("/"):
                continue
            if skipped(scope, path):
                continue
            number, sep2, text = rest.partition(":")
            if not os.access(path, os.R_OK):
                continue
            try:
                st = os.lstat(path)
            except OSError:
                continue
            row = hit_row(
                path,
                os.path.basename(path) or path,
                False,
                st,
                0,
                number if sep2 == ":" else "",
            )
            row["text"] = text if sep2 == ":" else rest
            emit_line(row)
            found += 1
            if found >= CAP:
                proc.kill()
                break
    finally:
        proc.wait()


def main(argv):
    if len(argv) < 2 or argv[1] not in ("names", "contents"):
        fail("usage")
    scope = flag(argv, "--scope", "folder")
    folder = flag(argv, "--root", "")
    query = flag(argv, "--query", "")
    hidden = flag(argv, "--hidden", "0")
    near = flag(argv, "--near", "")
    if not query or "\0" in query:
        return
    try:
        if argv[1] == "names":
            cmd_names(scope, folder, query, hidden, near)
        else:
            cmd_contents(scope, folder, query, hidden)
    except safe.Refuse as exc:
        fail(exc.reason)


if __name__ == "__main__":
    main(sys.argv)
