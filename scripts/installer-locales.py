#!/usr/bin/env python3
"""Validate languages.json and generate the installer's language data.

  installer-locales.py --check
  installer-locales.py --root BUNDLE --fallback-root REPO --strict \
      --json OUT.json --locale-gen OUT/locale.gen --branding-ts LANGDIR

--root is the tree the installed system comes from (the ISO bundle). A
bundle tagged before languages.json existed falls back to --fallback-root's
catalog, limited to the languages that bundle has translations for.
Reference files that are absent are skipped unless --strict.
"""
from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import installer_catalog as ic  # noqa: E402

REPO = Path(__file__).resolve().parent.parent


def _args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--root", type=Path, default=REPO)
    p.add_argument("--fallback-root", type=Path)
    p.add_argument("--strings", type=Path, default=REPO / "iso/releng/installer-strings.json")
    p.add_argument("--supported", type=Path, default=Path("/usr/share/i18n/SUPPORTED"))
    p.add_argument("--xkb-base", type=Path, default=Path("/usr/share/X11/xkb/rules/base.lst"))
    p.add_argument("--zone-tab", type=Path, default=Path("/usr/share/zoneinfo/zone.tab"))
    p.add_argument("--strict", action="store_true", help="fail when a reference file is missing")
    p.add_argument("--check", action="store_true")
    p.add_argument("--json", type=Path)
    p.add_argument("--locale-gen", type=Path)
    p.add_argument("--branding-ts", type=Path)
    return p.parse_args()


def _reference(path: Path, reader, strict: bool, notes: list[str]):
    value = reader(path)
    if value is None:
        if strict:
            raise ic.CatalogError(f"missing reference file {path}")
        notes.append(f"skipped checks against {path} (not present)")
    return value


def _installer_translations(args, translations: dict) -> dict[str, dict[str, str]]:
    """installer.* strings belong to the installer code, which is always the
    ISO working tree (--fallback-root), even when the bundle is an older tag;
    the bundle only fills in a language the working tree does not have."""
    if args.fallback_root is None:
        return translations
    own = ic.load_translations(args.fallback_root / ic.CONFIG)
    return {lid: {**translations.get(lid, {}), **own.get(lid, {})} for lid in set(translations) | set(own)}


def _catalog(args, notes: list[str]) -> tuple[list[dict], dict, list[str]]:
    config = args.root / ic.CONFIG
    translations = ic.load_translations(config)
    if not translations:
        raise ic.CatalogError(f"no translations under {config / 'translations'}")
    if (config / "languages.json").is_file() or args.fallback_root is None:
        rows = ic.load_catalog(config)
        missing = sorted({r["id"] for r in rows} - set(translations))
        extra = sorted(set(translations) - {r["id"] for r in rows})
        if missing:
            raise ic.CatalogError(f"languages.json lists {missing} but translations/<id>.json is missing")
        if extra:
            raise ic.CatalogError(f"translations {extra} have no entry in languages.json")
    else:
        rows = [r for r in ic.load_catalog(args.fallback_root / ic.CONFIG) if r["id"] in translations]
        notes.append(f"{config} has no languages.json; used {args.fallback_root}'s catalog")
    if not any(r["id"] == "en" for r in rows):
        raise ic.CatalogError("languages.json must keep 'en': it is the installer fallback")
    return rows, _installer_translations(args, translations), ic.load_layouts(config)


def _validate(rows, translations, layouts, args, notes) -> dict[str, str] | None:
    supported = _reference(args.supported, ic.read_supported, args.strict, notes)
    xkb = _reference(args.xkb_base, ic.read_xkb_layouts, args.strict, notes)
    zones = _reference(args.zone_tab, ic.read_zone_countries, args.strict, notes)
    problems = []
    if xkb is not None:
        problems += [f"keyboard-layouts.json: {x!r} is not an xkb layout" for x in layouts if x not in xkb]
    for row in rows:
        for cc, layout in row["countries"].items():
            if layout not in layouts:
                problems.append(f"language {row['id']}: layout {layout!r} ({cc}) is not in keyboard-layouts.json")
            if zones is not None and cc not in zones:
                problems.append(f"language {row['id']}: {cc} is not a country in zone.tab")
            try:
                ic.glibc_locale(row["id"], cc, supported)
            except ic.CatalogError as e:
                problems.append(str(e))
    en = translations.get("en", {})
    for group, entries in _strings(args).items():
        for e in entries:
            value = en.get(e["key"])
            if value is None:
                problems.append(f"installer-strings.json: {e['key']} missing from en.json")
            elif value != e["source"]:
                problems.append(f"installer-strings.json: en.json {e['key']} differs from the {group} source text")
    if problems:
        raise ic.CatalogError("\n".join(problems))
    return supported


def _strings(args) -> dict[str, list[dict]]:
    data = json.loads(args.strings.read_text(encoding="utf-8"))
    return {k: data.get(k) or [] for k in ("calamares", "branding")}


def _translated(entries, table: dict[str, str]) -> list[dict]:
    out = []
    for e in entries:
        text = table.get(e["key"])
        if text:
            out.append({"context": e["context"], "source": e["source"], "comment": e.get("comment", ""), "translation": text})
    return out


def build(rows, translations, layouts, supported, args) -> dict:
    strings, locales = _strings(args), []
    data: dict = {"locales": locales, "layouts": layouts, "strings": {}, "branding": {}}
    for row in rows:
        cal = row.get("calamares", row["id"])
        countries = [
            {"country": cc, "glibc": ic.glibc_locale(row["id"], cc, supported), "xkb": xkb}
            for cc, xkb in row["countries"].items()
        ]
        default = next(c for c in countries if c["country"] == row["country"])
        locales.append({"calamares": cal, "id": row["id"], "country": row["country"],
                        "glibc": default["glibc"], "xkb": default["xkb"], "countries": countries})
        if row["id"] != "en":
            data["strings"][cal] = _translated(strings["calamares"], translations[row["id"]])
            data["branding"][cal] = _translated(strings["branding"], translations[row["id"]])
    return data


def write_locale_gen(data: dict, supported, out: Path) -> None:
    defaults = {loc["glibc"] for loc in data["locales"]}
    lines = ["# Generated from languages.json by scripts/installer-locales.py.",
             "# Calamares uncomments the locale chosen at install time.", ""]
    for loc in data["locales"]:
        for c in loc["countries"]:
            line = ic.locale_gen_line(c["glibc"], supported)
            lines.append(line if c["glibc"] in defaults else f"#{line}")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_branding_ts(data: dict, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for code, entries in data["branding"].items():
        root = ET.Element("TS", version="2.1", language=code)
        contexts: dict[str, ET.Element] = {}
        for e in entries:
            ctx = contexts.get(e["context"])
            if ctx is None:
                ctx = contexts[e["context"]] = ET.SubElement(root, "context")
                ET.SubElement(ctx, "name").text = e["context"]
            msg = ET.SubElement(ctx, "message")
            ET.SubElement(msg, "source").text = e["source"]
            ET.SubElement(msg, "translation").text = e["translation"]
        ET.indent(root)
        body = ET.tostring(root, encoding="unicode")
        (out / f"calamares-modern_{code}.ts").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n' + body + "\n", encoding="utf-8")


def main() -> int:
    args = _args()
    notes: list[str] = []
    try:
        rows, translations, layouts = _catalog(args, notes)
        supported = _validate(rows, translations, layouts, args, notes)
        data = build(rows, translations, layouts, supported, args)
    except (ic.CatalogError, OSError, KeyError, json.JSONDecodeError) as e:
        print(f"installer-locales: ERROR:\n{e}", file=sys.stderr)
        return 1
    for n in notes:
        print(f"installer-locales: {n}", file=sys.stderr)
    if args.json:
        args.json.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if args.locale_gen:
        write_locale_gen(data, supported, args.locale_gen)
    if args.branding_ts:
        write_branding_ts(data, args.branding_ts)
    if args.check or not (args.json or args.locale_gen or args.branding_ts):
        combos = sum(len(loc["countries"]) for loc in data["locales"])
        print(f"installer-locales: ok — {len(data['locales'])} languages, {combos} language+country combinations, "
              f"{len(layouts)} keyboard layouts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
