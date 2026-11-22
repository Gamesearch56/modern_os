#!/usr/bin/env python3
"""Every translation key in en.json is used somewhere.

A key counts as used when its full name appears in quotes (QML, JS,
JSON descriptors, Lua, Python) or bare after `t ` in a shell script, or
when the code builds it from a quoted prefix such as "store.apps." + id
or `time.month.${n}`. Prefixes the code cannot spell out (catalogue
files, Calamares strings) are listed in DYNAMIC.

Usage: test-i18n-keys.py [--list]   (--list prints the unused keys)
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN = ROOT / "stow/modern/.config/modern/translations/en.json"
SOURCES = ("stow", "scripts", "install", "iso/releng", "iso/airootfs")
SUFFIXES = {".qml", ".js", ".json", ".sh", ".py", ".lua", ".desc", ".conf", ".txt"}
SKIP_DIRS = {"translations", "__pycache__", ".git"}

# Built from data files or by tools outside this tree.
DYNAMIC = (
    "installer.",       # Calamares strings via iso/releng/installer-strings.json
    "settings.langs.",  # one per languages.json entry
    "settings.kbLayouts.",  # one per keyboard-layouts.json entry
)

QUOTED = re.compile(r"""["'`]([A-Za-z][\w-]*(?:\.[\w-]+)+)["'`]""")
PREFIX = re.compile(r"""["'`]([A-Za-z][\w-]*(?:\.[\w-]+)*\.)(?:["'`]|\$\{)""")
SHELL_T = re.compile(r"\bt\s+([A-Za-z][\w-]*(?:\.[\w-]+)+)")


def keys(node, base=""):
    for name, value in node.items():
        path = base + name
        if isinstance(value, dict):
            yield from keys(value, path + ".")
        else:
            yield path


def tracked():
    # Gitignored files exist only on this machine; counting them hides keys CI sees as unused.
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--", *SOURCES],
                         capture_output=True, check=True).stdout
    return [ROOT / name for name in out.decode().split("\0") if name]


def corpus():
    for path in tracked():
        if not path.is_file() or SKIP_DIRS.intersection(path.relative_to(ROOT).parts):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore") if path.suffix in SUFFIXES or not path.suffix else ""
        # Extension-less files count only as scripts (scripts/modern).
        if path.suffix or text.startswith("#!"):
            yield text


def main():
    names = list(keys(json.loads(EN.read_text(encoding="utf-8"))))
    used, prefixes = set(), set(DYNAMIC)
    for text in corpus():
        used.update(QUOTED.findall(text))
        used.update(SHELL_T.findall(text))
        prefixes.update(PREFIX.findall(text))
    unused = [k for k in names if k not in used and not any(k.startswith(p) for p in prefixes)]
    if "--list" in sys.argv:
        print("\n".join(unused))
        return 0
    if unused:
        print("test-i18n-keys: FAIL %d unused keys in en.json:" % len(unused), file=sys.stderr)
        for k in unused:
            print("  " + k, file=sys.stderr)
        return 1
    print("test-i18n-keys: ok all %d keys are used" % len(names))
    return 0


if __name__ == "__main__":
    sys.exit(main())
