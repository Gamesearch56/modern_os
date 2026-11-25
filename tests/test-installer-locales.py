#!/usr/bin/env python3
"""languages.json -> installer data: generator, validation and the C++ it feeds.

Simulates adding a language (fr) and a region-coded one (pt via pt_BR) in a
throwaway tree, so a new language or layout is proven to reach the
installer without building an ISO. The generated Welcome functions are
compiled and run against Qt6 when g++ and Qt6Core are available.
"""
from __future__ import annotations

import copy
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / "scripts/installer-locales.py"
HOOK = ROOT / "iso/releng/calamares-limit-languages.py"
CONFIG = ROOT / "stow/modern/.config/modern"
STRINGS = ROOT / "iso/releng/installer-strings.json"
FAILED = []


def ok(msg: str) -> None:
    print(f"test-installer-locales: ok {msg}")


def fail(msg: str) -> None:
    print(f"test-installer-locales: FAIL {msg}", file=sys.stderr)
    FAILED.append(msg)


def run(*args: str | Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, GEN, *map(str, args)], capture_output=True, text=True)


def load_hook():
    spec = importlib.util.spec_from_file_location("limitlang", HOOK)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def write_refs(tmp: Path) -> list[str]:
    """Deterministic SUPPORTED / zone.tab / base.lst so CI hosts agree."""
    locales = ["en_US", "en_GB", "en_IE", "en_AU", "en_CA", "en_NZ", "en_ZA", "de_DE", "de_AT",
               "de_CH", "de_LI", "de_BE", "de_IT", "fr_FR", "fr_BE", "fr_CH", "pt_BR", "pt_PT"]
    (tmp / "SUPPORTED").write_text(
        "".join(f"{x}.UTF-8 UTF-8\n" for x in locales) + "en_IN UTF-8\nde_DE ISO-8859-1\n", encoding="utf-8")
    countries = sorted({x.split("_")[1] for x in locales} | {"IN", "JP"})
    (tmp / "zone.tab").write_text("# cc\tcoords\tTZ\n" + "".join(f"{c}\t+0\tZone/{c}\n" for c in countries))
    layouts = json.loads((CONFIG / "keyboard-layouts.json").read_text())["layouts"]
    (tmp / "base.lst").write_text("! model\n  pc105 Generic\n! layout\n" + "".join(f"  {x} X\n" for x in layouts)
                                  + "! variant\n  dvorak us: Dvorak\n")
    return ["--supported", str(tmp / "SUPPORTED"), "--zone-tab", str(tmp / "zone.tab"),
            "--xkb-base", str(tmp / "base.lst"), "--strict"]


def make_tree(tmp: Path, name: str) -> Path:
    root = tmp / name
    dst = root / "stow/modern/.config/modern"
    dst.mkdir(parents=True)
    shutil.copy(CONFIG / "languages.json", dst)
    shutil.copy(CONFIG / "keyboard-layouts.json", dst)
    shutil.copytree(CONFIG / "translations", dst / "translations")
    return root


def edit_json(path: Path, fn) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    fn(data)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def add_language(root: Path, lid: str, label: str, row: dict) -> None:
    cfg = root / "stow/modern/.config/modern"
    en = json.loads((cfg / "translations/en.json").read_text(encoding="utf-8"))
    fr = copy.deepcopy(en)

    def mark(node):
        for k, v in node.items():
            if isinstance(v, dict):
                mark(v)
            elif isinstance(v, str):
                node[k] = f"[{lid}] {v}"
    mark(fr.setdefault("installer", {}))
    (cfg / f"translations/{lid}.json").write_text(json.dumps(fr, ensure_ascii=False), encoding="utf-8")
    for path in (cfg / "translations").glob("*.json"):
        edit_json(path, lambda d: d["settings"]["langs"].__setitem__(lid, label))
    edit_json(cfg / "languages.json", lambda d: d["languages"].append(row))


def test_repo(refs: list[str]) -> None:
    r = run("--check", *refs)
    if r.returncode == 0 and "2 languages" in r.stdout:
        ok("repo languages.json validates against glibc, zone.tab and xkb")
    else:
        fail(f"repo catalog rejected: {r.stderr or r.stdout}")
    host = run("--check")
    if host.returncode == 0:
        ok("repo catalog validates against this host's glibc/xkb/zone files")
    else:
        fail(f"repo catalog rejected on this host: {host.stderr}")


def test_add_language(tmp: Path, refs: list[str]) -> dict:
    root = make_tree(tmp, "add")
    add_language(root, "fr", "French", {"id": "fr", "country": "FR", "countries": {"FR": "fr", "BE": "be", "CH": "ch"}})
    add_language(root, "pt", "Portuguese", {"id": "pt", "calamares": "pt_BR", "country": "BR",
                                            "countries": {"BR": "br", "PT": "pt"}})
    out = tmp / "add-out"
    out.mkdir()
    r = run("--root", root, "--json", out / "il.json", "--locale-gen", out / "locale.gen",
            "--branding-ts", out / "lang", *refs)
    if r.returncode != 0:
        fail(f"adding fr + pt broke generation: {r.stderr}")
        return {}
    data = json.loads((out / "il.json").read_text(encoding="utf-8"))
    rows = {x["calamares"]: x for x in data["locales"]}
    fr_be = [c for c in rows.get("fr", {}).get("countries", []) if c["country"] == "BE"]
    if (set(rows) == {"en", "de", "fr", "pt_BR"} and rows["fr"]["glibc"] == "fr_FR.UTF-8"
            and fr_be == [{"country": "BE", "glibc": "fr_BE.UTF-8", "xkb": "be"}]
            and rows["pt_BR"]["xkb"] == "br"):
        ok("a new language reaches Welcome, its countries and their keyboard layouts")
    else:
        fail(f"new language rows wrong: {rows.keys()}")
    gen = (out / "locale.gen").read_text().splitlines()
    if "fr_FR.UTF-8 UTF-8" in gen and "#fr_BE.UTF-8 UTF-8" in gen and "#pt_PT.UTF-8 UTF-8" in gen:
        ok("a new language's locales are in the installed locale.gen for localecfg")
    else:
        fail(f"locale.gen misses the new language: {gen}")
    mapped = len(json.loads(STRINGS.read_text())["calamares"])
    if len(data["strings"].get("fr", [])) == mapped and "en" not in data["strings"]:
        ok("a new language gets every installer string from its translation file")
    else:
        fail(f"fr strings {len(data['strings'].get('fr', []))} != {mapped}")
    ts = out / "lang/calamares-modern_fr.ts"
    msgs = ET.parse(ts).getroot().findall(".//message") if ts.is_file() else []
    if msgs and all(m.findtext("translation", "").startswith("[fr] ") for m in msgs):
        ok("a new language gets its own slideshow translation file")
    else:
        fail("calamares-modern_fr.ts missing or untranslated")
    lrelease = shutil.which("lrelease6") or shutil.which("lrelease-qt6") or shutil.which("lrelease")
    if lrelease and ts.is_file():
        r2 = subprocess.run([lrelease, ts, "-qm", out / "fr.qm"], capture_output=True, text=True)
        if r2.returncode == 0 and (out / "fr.qm").stat().st_size > 0:
            ok("generated slideshow .ts compiles with lrelease")
        else:
            fail(f"lrelease rejected the generated .ts: {r2.stderr}")
    return data


def test_rejects(tmp: Path, refs: list[str]) -> None:
    cfg = lambda root: root / "stow/modern/.config/modern"  # noqa: E731
    cases = [
        ("a translation without a catalog entry",
         lambda r: shutil.copy(cfg(r) / "translations/en.json", cfg(r) / "translations/fr.json"), "no entry in languages.json"),
        ("a catalog entry without a translation",
         lambda r: edit_json(cfg(r) / "languages.json", lambda d: d["languages"].append(
             {"id": "fr", "country": "FR", "countries": {"FR": "fr"}})), "translations/<id>.json is missing"),
        ("a layout missing from keyboard-layouts.json",
         lambda r: edit_json(cfg(r) / "languages.json", lambda d: d["languages"][1]["countries"].__setitem__("AT", "zz")),
         "is not in keyboard-layouts.json"),
        ("a layout xkb does not know",
         lambda r: edit_json(cfg(r) / "keyboard-layouts.json", lambda d: d["layouts"].append("zz")), "is not an xkb layout"),
        ("a language Calamares does not compile",
         lambda r: edit_json(cfg(r) / "languages.json", lambda d: d["languages"][1].__setitem__("calamares", "lv")),
         "Calamares has no compiled translation"),
        ("a country that is not in zone.tab",
         lambda r: edit_json(cfg(r) / "languages.json", lambda d: d["languages"][1]["countries"].__setitem__("XX", "de")),
         "XX is not a country in zone.tab"),
        ("a language + country glibc has no UTF-8 locale for",
         lambda r: edit_json(cfg(r) / "languages.json", lambda d: d["languages"][1]["countries"].__setitem__("JP", "de")),
         "de_JP: glibc has no UTF-8 locale"),
        ("a default country outside its countries",
         lambda r: edit_json(cfg(r) / "languages.json", lambda d: d["languages"][1].__setitem__("country", "FR")),
         "must be one of its countries"),
        ("an en.json installer string that no longer matches the code",
         lambda r: edit_json(cfg(r) / "translations/en.json", lambda d: d["installer"]["net"].__setitem__("title", "Net")),
         "installer.net.title differs"),
        ("removing en",
         lambda r: (edit_json(cfg(r) / "languages.json", lambda d: d.__setitem__("languages", d["languages"][1:])),
                    (cfg(r) / "translations/en.json").unlink()), "must keep 'en'"),
    ]
    for i, (label, mutate, needle) in enumerate(cases):
        root = make_tree(tmp, f"bad{i}")
        mutate(root)
        r = run("--root", root, "--check", *refs)
        if r.returncode != 0 and needle in r.stderr:
            ok(f"rejects {label}")
        else:
            fail(f"did not reject {label} with '{needle}': rc={r.returncode} {r.stderr.strip()}")
    root = make_tree(tmp, "missing-ref")
    r = run("--root", root, "--check", "--strict", "--supported", tmp / "nope")
    if r.returncode != 0 and "missing reference file" in r.stderr:
        ok("--strict (ISO build) refuses to skip a missing glibc SUPPORTED")
    else:
        fail("--strict accepted a missing SUPPORTED file")


def test_old_bundle(tmp: Path, refs: list[str]) -> None:
    root = make_tree(tmp, "old")
    cfg = root / "stow/modern/.config/modern"
    (cfg / "languages.json").unlink()
    for path in (cfg / "translations").glob("*.json"):
        edit_json(path, lambda d: d.pop("installer"))
    r = run("--root", root, "--fallback-root", ROOT, "--json", tmp / "old.json", *refs)
    data = json.loads((tmp / "old.json").read_text()) if r.returncode == 0 else {"locales": [], "strings": {}}
    mapped = len(json.loads(STRINGS.read_text())["calamares"])
    if ([x["calamares"] for x in data["locales"]] == ["en", "de"] and "used" in r.stderr
            and len(data["strings"].get("de", [])) == mapped):
        ok("an older bundle (no languages.json, no installer.* keys) still gets the full installer")
    else:
        fail(f"old bundle fallback: {r.stderr}")


def test_coverage() -> None:
    """Every installer string in our code has a translation-key mapping."""
    mapping = json.loads(STRINGS.read_text(encoding="utf-8"))
    have = {(e["context"], e["source"], e.get("comment", "")) for e in mapping["calamares"]}
    want = set()
    roots = [
        ROOT / "iso/releng/calamares-modernnet",
        ROOT / "iso/releng/calamares-modernapps",
    ]
    for cpp in (path for root in roots for path in root.glob("*.cpp")):
        for m in re.finditer(r'\btr\(\s*"((?:[^"\\]|\\.)*)"\s*(?:,\s*"([^"]*)")?\s*\)', cpp.read_text()):
            want.add((cpp.stem, m.group(1).replace("\\'", "'"), m.group(2) or ""))
    hook = load_hook()
    want.add(("UsersViewStep", re.search(r'tr\( "([^"]+)" \)', hook.USERS_NAME_NEW).group(1), ""))
    want.add(("Config", "Summary", "@label"))
    pieces = re.findall(r'"((?:[^"\\]|\\.)*)"', hook.FINISHED_TEXT_NEW)
    want.add(("FinishedPage", "".join(pieces[:-1]), pieces[-1]))
    missing = sorted(want - have)
    stale = sorted(have - want)
    if not missing and not stale:
        ok(f"all {len(want)} Calamares strings we add are mapped to translation keys")
    else:
        fail(f"installer-strings.json calamares: unmapped {missing}, stale {stale}")
    show = (ROOT / "iso/airootfs/etc/calamares/branding/modern/show.qml").read_text(encoding="utf-8")
    slides = set(re.findall(r'qsTr\("((?:[^"\\]|\\.)*)"\)', show))
    mapped = {e["source"] for e in mapping["branding"]}
    if slides == mapped:
        ok(f"all {len(slides)} slideshow strings are mapped to translation keys")
    else:
        fail(f"installer-strings.json branding: unmapped {sorted(slides - mapped)}, stale {sorted(mapped - slides)}")


CPP_MAIN = r"""
#include <QCoreApplication>
#include <QLocale>
#include <QString>
#include <cstdio>
%FUNCS%
int main()
{
    struct Case { const char* ui; const char* country; const char* lang; const char* layout; };
    const Case cases[] = { %CASES% };
    int bad = 0;
    for ( const auto& c : cases )
    {
        QLocale::setDefault( QLocale( QString::fromLatin1( c.ui ) ) );
        const QString country = QString::fromLatin1( c.country );
        const QString lang = modernWelcomeLanguage( country );
        const QString layout = modernWelcomeLayout( country );
        if ( lang != QLatin1String( c.lang ) || layout != QLatin1String( c.layout ) )
        {
            std::printf( "%s/%s -> %s %s (want %s %s)\n", c.ui, c.country, qPrintable( lang ),
                         qPrintable( layout ), c.lang, c.layout );
            ++bad;
        }
    }
    return bad;
}
"""


def test_cpp(tmp: Path, data: dict) -> None:
    gxx = shutil.which("g++")
    flags = subprocess.run(["pkg-config", "--cflags", "--libs", "Qt6Core"], capture_output=True, text=True) \
        if shutil.which("pkg-config") else None
    if not data or not gxx or not flags or flags.returncode != 0:
        ok("skipped compiling the Welcome functions (no g++ or Qt6Core here)")
        return
    hook = load_hook()
    funcs = hook.welcome_cpp_fn("modernWelcomeLanguage", "glibc", data) + \
        hook.welcome_cpp_fn("modernWelcomeLayout", "xkb", data)
    cases = [
        ("de_DE", "AT", "de_AT.UTF-8", "at"), ("de_DE", "CH", "de_CH.UTF-8", "ch"),
        ("de_DE", "US", "de_DE.UTF-8", "de"), ("de_DE", "", "de_DE.UTF-8", "de"),
        ("en_US", "GB", "en_GB.UTF-8", "gb"), ("en_US", "DE", "en_US.UTF-8", "us"),
        ("en_US", "AU", "en_AU.UTF-8", "us"), ("fr_FR", "BE", "fr_BE.UTF-8", "be"),
        ("fr_FR", "", "fr_FR.UTF-8", "fr"), ("pt_BR", "", "pt_BR.UTF-8", "br"),
        ("pt_BR", "PT", "pt_PT.UTF-8", "pt"), ("pt_PT", "", "pt_BR.UTF-8", "br"),
        ("lv_LV", "LV", "", ""),
    ]
    src = tmp / "welcome.cpp"
    src.write_text(CPP_MAIN.replace("%FUNCS%", funcs).replace(
        "%CASES%", ", ".join("{ \"%s\", \"%s\", \"%s\", \"%s\" }" % c for c in cases)), encoding="utf-8")
    build = subprocess.run([gxx, "-std=c++17", "-Wall", "-Werror", "-fPIC", str(src), "-o", str(tmp / "welcome"),
                            *flags.stdout.split()], capture_output=True, text=True)
    if build.returncode != 0:
        fail(f"generated Welcome C++ does not compile: {build.stderr[:800]}")
        return
    res = subprocess.run([str(tmp / "welcome")], capture_output=True, text=True)
    if res.returncode == 0:
        ok(f"generated Welcome C++ compiles with -Werror and maps {len(cases)} language/country cases")
    else:
        fail(f"Welcome mapping wrong:\n{res.stdout}")


def test_real_source(tmp: Path, data: dict) -> None:
    """MODERN_CALAMARES_SRC=<unpacked calamares-x.y.z>: run the hook for real."""
    import os
    src = os.environ.get("MODERN_CALAMARES_SRC")
    if not src or not data:
        ok("skipped the real Calamares source run (set MODERN_CALAMARES_SRC to an unpacked tarball)")
        return
    hookdir, tree = tmp / "hook", tmp / "calamares"
    hookdir.mkdir()
    shutil.copy(HOOK, hookdir)
    shutil.copytree(ROOT / "iso/releng/calamares-modernnet", hookdir / "calamares-modernnet")
    shutil.copytree(ROOT / "iso/releng/calamares-modernapps", hookdir / "calamares-modernapps")
    (hookdir / "installer-locales.json").write_text(json.dumps(data), encoding="utf-8")
    shutil.copytree(src, tree)
    runs = [subprocess.run([sys.executable, hookdir / HOOK.name, tree], capture_output=True, text=True) for _ in (1, 2)]
    if any(r.returncode for r in runs):
        fail(f"hook failed on {src}: {runs[0].stderr or runs[1].stderr}")
        return
    cfg = (tree / "src/modules/locale/Config.cpp").read_text(encoding="utf-8")
    if cfg.count("modernWelcomeLanguage( const QString& country )") == 1 and '"fr_BE.UTF-8"' in cfg:
        ok(f"hook patches {Path(src).name} once, with the new language's regional locales")
    else:
        fail("hook inserted the Welcome function zero or several times")
    lrelease = shutil.which("lrelease6") or shutil.which("lrelease")
    for code in ("fr", "pt_BR"):
        ts = tree / f"lang/calamares_{code}.ts"
        r = subprocess.run([lrelease, ts, "-qm", tmp / f"{code}.qm"], capture_output=True, text=True) if lrelease else None
        if r is not None and r.returncode == 0:
            ok(f"patched calamares_{code}.ts compiles with lrelease")
        elif r is not None:
            fail(f"patched calamares_{code}.ts does not compile: {r.stderr}")


def main() -> int:
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        refs = write_refs(tmp)
        test_repo(refs)
        data = test_add_language(tmp, refs)
        test_rejects(tmp, refs)
        test_old_bundle(tmp, refs)
        test_coverage()
        test_cpp(tmp, data)
        test_real_source(tmp, data)
    return 1 if FAILED else 0


if __name__ == "__main__":
    raise SystemExit(main())
