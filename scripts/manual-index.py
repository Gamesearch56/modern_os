#!/usr/bin/env python3
"""Index the ModernOS documentation for the Manual app.

Prints one JSON array: the user manual (docs/manual, in file-name order,
which is chapter order) followed by the technical reference (README,
CONTRIBUTING and docs/*.md, by title). Each entry carries the full
markdown, so the app can search every document without reading files
itself, and the rich text it shows (lib/manual_markdown.py).

Usage: manual-index.py [REPO]
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
from manual_markdown import plain, to_html  # noqa: E402


def title_of(text: str, fallback: str) -> str:
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("# "):
            return plain(line[2:])
    return fallback


def entry(repo: str, rel: str, group: str) -> dict | None:
    path = os.path.join(repo, rel)
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError):
        return None
    name = os.path.splitext(os.path.basename(rel))[0]
    return {
        "path": path,
        "rel": rel,
        "group": group,
        "title": title_of(text, name),
        "text": text,
        "html": to_html(text),
    }


def markdown_in(repo: str, sub: str) -> list[str]:
    try:
        names = os.listdir(os.path.join(repo, sub))
    except OSError:
        return []
    return sorted(os.path.join(sub, n) for n in names if n.endswith(".md"))


def index(repo: str) -> list[dict]:
    manual = [entry(repo, rel, "manual") for rel in markdown_in(repo, "docs/manual")]
    reference = [entry(repo, rel, "reference") for rel in ["README.md", "CONTRIBUTING.md"]]
    reference += [entry(repo, rel, "reference") for rel in markdown_in(repo, "docs")]
    reference = sorted((e for e in reference if e), key=lambda e: e["title"].lower())
    return [e for e in manual if e] + reference


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, ".."))
    json.dump(index(repo), sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
