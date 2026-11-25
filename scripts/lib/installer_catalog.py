"""Language + country + keyboard catalog shared by the desktop and the ISO.

languages.json lists the UI languages (one per translations/<id>.json) with
the countries each is offered in and the keyboard layout that country uses.
Everything the installer needs (Welcome languages, locale per timezone
country, keyboard per locale, locale.gen, translated strings) is derived from
it, so adding a language or layout never needs a hand-edited installer file.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

CONFIG = Path("stow/modern/.config/modern")

# Calamares 3.4.2 CMakeLists.txt _tx_complete + _tx_good + _tx_ok, plus en.
# Only these are compiled into a release build; the ISO hook re-checks the
# real source tree, this copy lets CI fail long before an ISO build.
CALAMARES_TRANSLATIONS = frozenset(
    """en ar az ca cs_CZ de es es_AR fi_FI fr he hu id ja kk ko lg nb pl pt_BR
    ru sv tg tr_TR uk zh_CN zh_TW az_AZ bg fur hr is it_IT ka lt pt_PT sk sq uz
    as ast be bn da el en_GB eo es_MX et eu fa gl hi ia ml mr nl oc ro si sl sr
    th vi""".split()
)

ID_RE = re.compile(r"^[a-z]{2,3}$")
CC_RE = re.compile(r"^[A-Z]{2}$")
XKB_RE = re.compile(r"^[a-z]{2,8}$")
CAL_RE = re.compile(r"^[a-z]{2,3}(_[A-Z]{2})?$")


class CatalogError(Exception):
    pass


def _load(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise CatalogError(f"missing {path}") from None
    except json.JSONDecodeError as e:
        raise CatalogError(f"{path}: invalid JSON ({e})") from None


def read_supported(path: Path | None) -> dict[str, str] | None:
    """glibc SUPPORTED as {locale: charset}; None when the file is absent."""
    if path is None or not path.is_file():
        return None
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        fields = line.split()
        if len(fields) == 2 and not line.startswith("#"):
            out[fields[0]] = fields[1]
    return out


def read_xkb_layouts(path: Path | None) -> set[str] | None:
    if path is None or not path.is_file():
        return None
    section, out = "", set()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("! "):
            section = line[2:].strip()
        elif section == "layout" and line.strip():
            out.add(line.split()[0])
    return out


def read_zone_countries(path: Path | None) -> set[str] | None:
    if path is None or not path.is_file():
        return None
    return {
        line.split("\t", 1)[0]
        for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    }


def glibc_locale(lang: str, country: str, supported: dict[str, str] | None) -> str:
    utf8 = f"{lang}_{country}.UTF-8"
    if supported is None or utf8 in supported:
        return utf8
    bare = f"{lang}_{country}"
    if supported.get(bare) == "UTF-8":
        return bare
    raise CatalogError(f"{lang}_{country}: glibc has no UTF-8 locale for this language and country")


def locale_gen_line(locale: str, supported: dict[str, str] | None) -> str:
    charset = (supported or {}).get(locale, "UTF-8")
    return f"{locale} {charset}"


def load_catalog(config: Path) -> list[dict]:
    """Validated catalog rows; raises CatalogError with every problem found."""
    data = _load(config / "languages.json")
    rows = data.get("languages")
    if not isinstance(rows, list) or not rows:
        raise CatalogError(f"{config / 'languages.json'}: 'languages' must be a non-empty list")
    problems, seen, cal_seen = [], set(), set()
    for i, row in enumerate(rows):
        where = f"languages[{i}]"
        if not isinstance(row, dict):
            problems.append(f"{where}: must be an object")
            continue
        lid = row.get("id")
        if not isinstance(lid, str) or not ID_RE.match(lid):
            problems.append(f"{where}: id must be 2-3 lowercase letters, got {lid!r}")
            continue
        where = f"language {lid}"
        if lid in seen:
            problems.append(f"{where}: listed twice")
        seen.add(lid)
        cal = row.get("calamares", lid)
        if not isinstance(cal, str) or not CAL_RE.match(cal):
            problems.append(f"{where}: calamares code {cal!r} must look like 'fr' or 'pt_BR'")
        elif cal not in CALAMARES_TRANSLATIONS:
            problems.append(
                f"{where}: Calamares has no compiled translation {cal!r}; "
                f"set \"calamares\" to one of: {' '.join(sorted(c for c in CALAMARES_TRANSLATIONS if c.startswith(lid)) or ['(none for this language)'])}"
            )
        elif cal in cal_seen:
            problems.append(f"{where}: calamares code {cal!r} used twice")
        cal_seen.add(cal)
        countries = row.get("countries")
        if not isinstance(countries, dict) or not countries:
            problems.append(f"{where}: countries must map at least one country code to a keyboard layout")
            continue
        for cc, xkb in countries.items():
            if not CC_RE.match(str(cc)):
                problems.append(f"{where}: country {cc!r} must be two uppercase letters")
            if not isinstance(xkb, str) or not XKB_RE.match(xkb):
                problems.append(f"{where}: layout {xkb!r} for {cc} is not an xkb layout id")
        if row.get("country") not in countries:
            problems.append(f"{where}: country {row.get('country')!r} must be one of its countries")
    if problems:
        raise CatalogError("\n".join(problems))
    return rows


def load_layouts(config: Path) -> list[str]:
    layouts = _load(config / "keyboard-layouts.json").get("layouts")
    if not isinstance(layouts, list) or not layouts or layouts[0] != "us":
        raise CatalogError("keyboard-layouts.json: 'layouts' must be a list starting with 'us'")
    bad = [x for x in layouts if not isinstance(x, str) or not XKB_RE.match(x)]
    if bad or len(set(layouts)) != len(layouts):
        raise CatalogError(f"keyboard-layouts.json: invalid or duplicate layouts {bad}")
    return layouts


def flatten(tree: dict, prefix: str = "") -> dict[str, str]:
    out: dict[str, str] = {}
    for key, value in tree.items():
        path = f"{prefix}{key}"
        if isinstance(value, dict):
            out.update(flatten(value, path + "."))
        elif isinstance(value, str):
            out[path] = value
    return out


def load_translations(config: Path) -> dict[str, dict[str, str]]:
    out = {}
    for path in sorted((config / "translations").glob("*.json")):
        out[path.stem] = flatten(_load(path))
    return out
