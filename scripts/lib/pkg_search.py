#!/usr/bin/env python3
"""Filter pacman -Ss text down to hits a typed query should show.

A hit is a package whose name contains the query, or whose description
contains that query as a whole word. Letters inside another word
("oll" inside "collection") are not a hit. Names that start with the
query come first, then other name hits, then description hits.
"""
import argparse
import json
import os
import re
import sys

_LINE = re.compile(r"^([a-z0-9-]+)/([a-z0-9][a-z0-9.+_-]*)\s+(\S+)(.*)$")


def rank(name, desc, query):
    q = query.casefold()
    if not q:
        return None
    n = name.casefold()
    if n.startswith(q):
        return 0
    if q in n:
        return 1
    if re.search(r"\b" + re.escape(q) + r"\b", desc or "", re.IGNORECASE):
        return 2
    return None


def parse(text):
    lines = text.splitlines()
    rows = []
    i = 0
    while i < len(lines):
        m = _LINE.match(lines[i])
        if not m:
            i += 1
            continue
        repo, name, version, rest = m.group(1), m.group(2), m.group(3), m.group(4)
        desc = ""
        if i + 1 < len(lines) and lines[i + 1].startswith("    "):
            desc = lines[i + 1].strip()
            i += 2
        else:
            i += 1
        rows.append({
            "name": name,
            "repo": repo,
            "version": version,
            "desc": desc,
            "installed": "[installed]" in rest,
            "_i": len(rows),
        })
    return rows


def select(text, query, limit, curated=None, seen=None):
    rows = list(curated or [])
    skip = {r.get("name") for r in rows if isinstance(r, dict)}
    for n in seen or []:
        if n:
            skip.add(n)
    hits = []
    for pkg in parse(text):
        if pkg["name"] in skip:
            continue
        r = rank(pkg["name"], pkg["desc"], query)
        if r is None:
            continue
        hits.append((r, pkg["_i"], pkg))
    hits.sort(key=lambda t: (t[0], t[1]))
    for _, _, pkg in hits:
        if len(rows) >= limit:
            break
        pkg.pop("_i", None)
        rows.append(pkg)
    return rows[:limit]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--query", required=True)
    p.add_argument("--limit", type=int, default=50)
    p.add_argument("--curated-env", action="store_true")
    p.add_argument("--seen-env", action="store_true")
    args = p.parse_args()
    limit = args.limit if args.limit > 0 else 1
    curated = []
    if args.curated_env:
        try:
            parsed = json.loads(os.environ.get("CURATED") or "[]")
        except ValueError:
            parsed = []
        curated = parsed if isinstance(parsed, list) else []
    seen = []
    if args.seen_env:
        seen = [n.strip() for n in os.environ.get("SEEN", "").splitlines() if n.strip()]
    rows = select(sys.stdin.read(), args.query, limit, curated, seen)
    print(json.dumps(rows, ensure_ascii=False))


if __name__ == "__main__":
    main()
