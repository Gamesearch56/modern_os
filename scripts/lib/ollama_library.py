#!/usr/bin/env python3
"""Turn an Ollama library page into families and their sizes.

Search returns every family on the page, not a short sample. Sizes are
the plain ones (4b, 8b, 30b-a3b). Quantized copies stay off the list.
"""
import argparse
import html
import json
import re
import sys
from urllib.parse import quote

_NAME = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._-]{0,80}"
    r"(?:/[A-Za-z0-9][A-Za-z0-9._-]{0,80})?"
    r"(?::[A-Za-z0-9][A-Za-z0-9._-]{0,48})?$"
)
_FAMILY = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._-]{0,80}(?:/[A-Za-z0-9][A-Za-z0-9._-]{0,80})?$"
)
_SIZE = re.compile(r"^[0-9]+(?:\.[0-9]+)?b$")
_MOE = re.compile(r"^[0-9]+(?:\.[0-9]+)?b-a[0-9]+(?:\.[0-9]+)?b$")
_QUANT = re.compile(r"(q[0-9]|fp16|bf16|f16|mlx|nvfp|mxfp)", re.IGNORECASE)
_TAG = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,48}$")
# Sizes printed on a library card: 4b, 270m, e2b, 30b-a3b.
_CHIP = re.compile(
    r"^(?:e)?[0-9]+(?:\.[0-9]+)?[mb](?:-a[0-9]+(?:\.[0-9]+)?[mb])?$",
    re.IGNORECASE,
)

# Shown when the library page cannot be reached.
CURATED = ["qwen3", "llama3.2", "gemma3", "mistral", "deepseek-r1"]


def valid_name(name):
    return bool(name) and ".." not in name and _NAME.match(name) is not None


def clean_query(query):
    text = re.sub(r"[^A-Za-z0-9 ._:/+-]", "", str(query or ""))
    return text.strip()[:60]


def search_url(query):
    return "https://ollama.com/search?q=" + quote(clean_query(query), safe="")


def index_url():
    return "https://ollama.com/library?sort=popular"


def tags_url(name):
    family = str(name or "").split(":", 1)[0]
    if not _FAMILY.match(family) or ".." in family:
        return ""
    return "https://ollama.com/library/" + quote(family, safe="") + "/tags"


def _caps(chunk):
    found = []
    for raw in re.findall(r">\s*(tools|thinking|vision|embedding)\s*<", chunk, re.I):
        key = raw.lower()
        if key not in found:
            found.append(key)
    return found


def use_case(name, caps):
    """Pick a use key from the family name and the library badges.

    The key is translated in the shell. also lists extra abilities that
    change the choice (tools, thinking, vision) without hiding the main use.
    """
    text = str(name or "").split(":", 1)[0].lower()
    have = {str(item).lower() for item in (caps or [])}
    if "embedding" in have or "embed" in text:
        primary = "embed"
    elif "ocr" in text:
        primary = "ocr"
    elif "translate" in text:
        primary = "translate"
    elif any(tok in text for tok in ("coder", "code", "devstral")):
        primary = "code"
    elif (
        "vision" in have
        or any(tok in text for tok in ("vision", "llava", "moondream"))
        or text.endswith("vl")
        or "-vl" in text
    ):
        primary = "vision"
    elif any(tok in text for tok in ("-r1", "reasoning", "qwq", "cogito")) or text.endswith("r1"):
        primary = "reason"
    elif any(tok in text for tok in ("dolphin", "uncensored", "wizard")):
        primary = "open"
    else:
        primary = "chat"
    also = []
    if "thinking" in have and primary != "reason":
        also.append("think")
    if "tools" in have and primary not in ("embed", "ocr"):
        also.append("tools")
    if "vision" in have and primary != "vision":
        also.append("vision")
    return primary, also


def _size_key(tag):
    match = re.match(r"(?:e)?([0-9]+(?:\.[0-9]+)?)([mb])", str(tag), re.IGNORECASE)
    if not match:
        return 1e9
    number = float(match.group(1))
    if match.group(2).lower() == "m":
        number /= 1000.0
    return number


def _sizes(chunk):
    found = []
    for raw in re.findall(r"text-blue-600[^>]*>([^<]+)</span>", chunk):
        tag = raw.strip().lower()
        if tag in found or not _CHIP.match(tag):
            continue
        found.append(tag)
    found.sort(key=_size_key)
    return found


def _row(name, desc, caps, sizes=None):
    chosen = [tag for tag in (sizes or []) if tag]
    # A card with no size still has the default tag, so the row can be installed.
    if not chosen and ":" not in str(name or ""):
        chosen = ["latest"]
    primary, also = use_case(name, caps)
    return {"name": name, "desc": desc, "use": primary, "also": also, "sizes": chosen}


def parse_search(page):
    rows = []
    seen = set()
    for chunk in str(page or "").split("<li"):
        href = re.search(r'href="/library/([^"#?]+)"', chunk)
        if not href:
            continue
        family = href.group(1).split(":", 1)[0]
        if family in seen or not _FAMILY.match(family) or ".." in family:
            continue
        seen.add(family)
        desc = re.search(r"<p\b[^>]*>([^<]+)</p>", chunk)
        title = re.search(r"<h2\b[^>]*>.*?<span[^>]*>([^<]+)</span>", chunk, re.S)
        text = ""
        if desc:
            text = desc.group(1).strip()
        elif title:
            text = title.group(1).strip()
        text = re.sub(r"\s+", " ", html.unescape(text)).strip()
        rows.append(_row(family, text, _caps(chunk), _sizes(chunk)))
    return rows


def parse_tags(page, family):
    tags = []
    seen = set()
    pattern = r'href="/library/' + re.escape(family) + r':([^"#?]+)"'
    for match in re.finditer(pattern, str(page or "")):
        tag = match.group(1)
        if tag in seen or not _TAG.match(tag):
            continue
        seen.add(tag)
        tags.append(tag)
    return tags


def _to_bytes(number, unit):
    mult = {"MB": 1024 ** 2, "GB": 1024 ** 3, "TB": 1024 ** 4}
    return int(round(float(number) * mult[unit]))


def tag_bytes(page, family):
    """Download size printed beside each tag on the tags page."""
    text = str(page or "")
    token = 'href="/library/' + family + ":"
    sizes = {}
    start = 0
    while True:
        at = text.find(token, start)
        if at < 0:
            break
        name_at = at + len(token)
        end = text.find('"', name_at)
        if end < 0:
            break
        tag = text[name_at:end]
        nxt = text.find(token, end + 1)
        window = text[end:nxt if nxt > 0 else end + 4000]
        match = re.search(r">([0-9]+(?:\.[0-9]+)?)\s*(GB|MB|TB)</p>", window, re.I)
        if not match:
            match = re.search(r"[•·]\s*([0-9]+(?:\.[0-9]+)?)\s*(GB|MB|TB)\b", window, re.I)
        if match and _TAG.match(tag) and tag not in sizes:
            sizes[tag] = _to_bytes(match.group(1), match.group(2).upper())
        start = end + 1
    return sizes


def pick_tags(tags, query_tag):
    chosen = []
    seen = set()
    for tag in tags:
        if tag in seen or _QUANT.search(tag):
            continue
        if _SIZE.match(tag) or _MOE.match(tag):
            seen.add(tag)
            chosen.append(tag)
    chosen.sort(key=_size_key)
    if query_tag and _TAG.match(query_tag) and query_tag not in chosen:
        chosen.append(query_tag)
    if chosen:
        return chosen
    if "latest" in tags:
        return ["latest"]
    return [""]


def rows_for(query, page):
    query = clean_query(query)
    out = parse_search(page)
    seen = {row["name"] for row in out}
    if ":" in query and valid_name(query) and query not in seen:
        out.append(_row(query, "", []))
    return out


def tag_rows(family, page):
    family = str(family or "").split(":", 1)[0]
    if not _FAMILY.match(family) or ".." in family:
        return []
    rows = []
    sizes = tag_bytes(page, family)
    for tag in pick_tags(parse_tags(page, family), ""):
        name = family if not tag else family + ":" + tag
        if not valid_name(name):
            continue
        row = {"name": name}
        if tag in sizes:
            row["bytes"] = sizes[tag]
        rows.append(row)
    return rows


def curated_rows():
    return [_row(name, "", []) for name in CURATED if valid_name(name)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("search", "names", "url", "index-url", "tags-url", "tags", "check"))
    parser.add_argument("--query", default="")
    parser.add_argument("--name", default="")
    parser.add_argument("--html", default="")
    args = parser.parse_args()
    if args.mode == "check":
        if not valid_name(args.name):
            return 1
        print(args.name)
        return 0
    if args.mode == "url":
        print(search_url(args.query))
        return 0
    if args.mode == "index-url":
        print(index_url())
        return 0
    if args.mode == "tags-url":
        url = tags_url(args.name)
        if not url:
            return 1
        print(url)
        return 0
    if args.mode == "names":
        try:
            with open(args.html, encoding="utf-8") as handle:
                html = handle.read()
        except OSError:
            html = ""
        for row in parse_search(html):
            print(row["name"])
        return 0
    page = ""
    if args.html:
        try:
            with open(args.html, encoding="utf-8") as handle:
                page = handle.read()
        except OSError:
            page = ""
    if args.mode == "tags":
        print(json.dumps(tag_rows(args.name, page), ensure_ascii=False))
        return 0
    if not clean_query(args.query) and not page:
        print(json.dumps(curated_rows(), ensure_ascii=False))
        return 0
    if not clean_query(args.query):
        found = parse_search(page)
        print(json.dumps(found or curated_rows(), ensure_ascii=False))
        return 0
    print(json.dumps(rows_for(args.query, page), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
