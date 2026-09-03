#!/usr/bin/env python3
"""Live ISO: Calamares lists every xkb layout from rules XML.

Keep the layouts in installer-locales.json — the same pair Settings →
Keyboard offers. Drop variants so only Default remains. Overlay only;
the squashfs copy is what unpackfs installs.
"""
from __future__ import annotations

import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

RULES = (
    "/usr/share/X11/xkb/rules/base.xml",
    "/usr/share/X11/xkb/rules/evdev.xml",
    "/usr/share/X11/xkb/rules/base.extras.xml",
    "/usr/share/X11/xkb/rules/evdev.extras.xml",
)
# Calamares KeyboardLayoutModel reads base.lst, not the XML.
LST = (
    "/usr/share/X11/xkb/rules/base.lst",
    "/usr/share/X11/xkb/rules/evdev.lst",
)


def _locales_paths() -> list[Path]:
    paths: list[Path] = []
    env = os.environ.get("MODERN_INSTALLER_LOCALES")
    if env:
        paths.append(Path(env))
    here = Path(__file__).resolve()
    paths.append(Path("/usr/lib/modern/installer-locales.json"))
    paths.append(here.parent / "installer-locales.json")
    try:
        paths.append(here.parents[4] / "releng" / "installer-locales.json")
    except IndexError:
        pass
    return paths


def load_keep_layouts() -> set[str]:
    for path in _locales_paths():
        if not path.is_file():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        keep = {str(loc["xkb"]) for loc in data.get("locales") or [] if loc.get("xkb")}
        if keep:
            return keep
    return {"us", "de"}


KEEP_LAYOUTS = load_keep_layouts()


def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1]


def child(el: ET.Element, name: str) -> ET.Element | None:
    for c in el:
        if local_name(c.tag) == name:
            return c
    return None


def layout_name(layout: ET.Element) -> str:
    item = child(layout, "configItem")
    if item is None:
        return ""
    name = child(item, "name")
    return (name.text or "").strip() if name is not None else ""


def filter_file(path: str) -> None:
    tree = ET.parse(path)
    root = tree.getroot()
    for layout_list in root.iter():
        if local_name(layout_list.tag) != "layoutList":
            continue
        for layout in list(layout_list):
            if local_name(layout.tag) != "layout":
                continue
            if layout_name(layout) not in KEEP_LAYOUTS:
                layout_list.remove(layout)
                continue
            variants = child(layout, "variantList")
            if variants is None:
                continue
            for variant in list(variants):
                variants.remove(variant)
    tree.write(path, encoding="UTF-8", xml_declaration=True)


def filter_lst(path: str) -> None:
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    out: list[str] = []
    section = ""
    for line in lines:
        if line.startswith("!"):
            parts = line.split()
            section = parts[1] if len(parts) > 1 else ""
            out.append(line)
            continue
        if section == "layout":
            key = line.split()[0] if line.split() else ""
            if key in KEEP_LAYOUTS:
                out.append(line)
            continue
        if section == "variant":
            continue
        out.append(line)
    Path(path).write_text("".join(out), encoding="utf-8")


def main() -> int:
    seen: set[str] = set()
    for path in RULES:
        if not os.path.isfile(path):
            continue
        real = os.path.realpath(path)
        if real in seen:
            continue
        seen.add(real)
        try:
            filter_file(real)
        except (OSError, ET.ParseError) as exc:
            print(f"live-xkb-filter: {real}: {exc}", file=sys.stderr)
            return 1
    for path in LST:
        if not os.path.isfile(path):
            continue
        real = os.path.realpath(path)
        if real in seen:
            continue
        seen.add(real)
        try:
            filter_lst(real)
        except OSError as exc:
            print(f"live-xkb-filter: {real}: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
