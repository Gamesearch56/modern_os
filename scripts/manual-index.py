#!/usr/bin/env python3
"""Index the ModernOS documentation for the Manual app.

Prints one JSON array: the user manual (docs/manual) followed by the
technical reference (README, CONTRIBUTING and docs/*.md), each split into
the sections below. Each entry carries the full
markdown, so the app can search every document without reading files
itself, and the rich text it shows (lib/manual_markdown.py).

Usage: manual-index.py [REPO]
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
from manual_markdown import plain, to_html  # noqa: E402


# Sections shown in the sidebar, in this order. Manual chapters are listed
# by their number, reference documents by path. A file in no section goes
# to "more" so a new document is never hidden.
MANUAL_SECTIONS = [
    ("start", ["01", "02"]),
    ("desktop", ["03", "04", "05", "06"]),
    ("personal", ["07", "08"]),
    ("apps", ["09", "10", "11"]),
    ("care", ["12", "13", "14"]),
]
REFERENCE_SECTIONS = [
    ("project", ["README.md", "docs/ARCHITECTURE.md", "docs/DECISIONS.md", "CONTRIBUTING.md", "docs/GIT.md"]),
    ("look", ["docs/DESIGN.md", "docs/THEMING.md", "docs/MOTION.md", "docs/I18N.md", "docs/KEYBINDS.md"]),
    ("shell", ["docs/WIDGETS.md", "docs/SETTINGS.md", "docs/EDITOR.md", "docs/VIEWER.md",
               "docs/PLAYER.md", "docs/MANUAL.md", "docs/BUGREPORT.md"]),
    ("system", ["docs/INSTALL.md", "docs/CUTOVER.md", "docs/BOOT.md", "docs/ISOLATION.md", "docs/SECURITY.md",
                "docs/BACKUP.md", "docs/GAMING.md", "docs/CURSOR-SETUP.md", "docs/TROUBLESHOOTING.md",
                "docs/MODDING.md", "docs/CENSUS.md"]),
]


def chapter_of(rel: str) -> str:
    return os.path.basename(rel).split("-", 1)[0]


def placed(entries: list[dict], sections: list, member) -> list[dict]:
    out, used = [], set()
    for sid, members in sections:
        picked = [e for e in entries if member(e) in members and e["rel"] not in used]
        for e in picked:
            e["section"] = sid
            used.add(e["rel"])
        out += picked
    for e in entries:
        if e["rel"] not in used:
            e["section"] = "more"
            out.append(e)
    return out


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
        "html": to_html(text, os.path.dirname(path)),
    }


def markdown_in(repo: str, sub: str) -> list[str]:
    try:
        names = os.listdir(os.path.join(repo, sub))
    except OSError:
        return []
    return sorted(os.path.join(sub, n) for n in names if n.endswith(".md"))


def index(repo: str) -> list[dict]:
    manual = [e for e in (entry(repo, rel, "manual") for rel in markdown_in(repo, "docs/manual")) if e]
    for e in manual:
        e["number"] = int(chapter_of(e["rel"])) if chapter_of(e["rel"]).isdigit() else 0
    reference = [entry(repo, rel, "reference") for rel in ["README.md", "CONTRIBUTING.md"]]
    reference += [entry(repo, rel, "reference") for rel in markdown_in(repo, "docs")]
    reference = [e for e in reference if e]
    for e in reference:
        e["number"] = 0
    order = {rel: i for _, members in REFERENCE_SECTIONS for i, rel in enumerate(members)}
    reference.sort(key=lambda e: (order.get(e["rel"], len(order)), e["title"].lower()))
    return placed(manual, MANUAL_SECTIONS, lambda e: chapter_of(e["rel"])) + \
        placed(reference, REFERENCE_SECTIONS, lambda e: e["rel"])


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, ".."))
    json.dump(index(repo), sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
