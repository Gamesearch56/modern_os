#!/usr/bin/env bash
# Store catalog: every curated app sits in a category, has a translated
# one-liner in en + de, and every category has a nav label.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$ROOT/stow/modern/.config/modern"

CATALOG="$CFG/store/catalog.json" EN="$CFG/translations/en.json" DE="$CFG/translations/de.json" python3 - <<'PY'
import json, os, re, sys

cat = json.load(open(os.environ["CATALOG"]))
langs = {k: json.load(open(os.environ[k]))["store"] for k in ("EN", "DE")}
fail = []
apps = cat.get("apps", {})
listed = set()
for c in cat.get("categories", []):
    for lang, tr in langs.items():
        if c["id"] not in tr.get("categories", {}):
            fail.append(f"{lang}: store.categories.{c['id']} missing")
    for p in c.get("packages", []):
        listed.add(p)
        if p not in apps:
            fail.append(f"{p} is in category {c['id']} but has no apps entry")
for p in cat.get("popular", []):
    if p not in apps:
        fail.append(f"popular {p} has no apps entry")
for p, a in apps.items():
    if p not in listed:
        fail.append(f"{p} is in apps but in no category")
    if not a.get("title"):
        fail.append(f"{p} has no title")
    key = re.sub(r"[^a-z0-9]", "_", p)
    for lang, tr in langs.items():
        if not tr.get("apps", {}).get(key):
            fail.append(f"{lang}: store.apps.{key} missing")
for lang, tr in langs.items():
    for key in tr.get("apps", {}):
        if key not in {re.sub(r"[^a-z0-9]", "_", p) for p in apps}:
            fail.append(f"{lang}: store.apps.{key} has no catalog app")
for f in fail:
    print(f"test-store-catalog: FAIL {f}", file=sys.stderr)
if fail:
    sys.exit(1)
print(f"test-store-catalog: ok {len(apps)} apps, {len(cat['categories'])} categories, en + de")
PY
