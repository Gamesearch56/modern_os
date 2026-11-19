#!/usr/bin/env python3
"""Brave LLM context for the local assistant.

GET /res/v1/llm/context returns extracted page text, not a result list.
The key stays in this process. Nothing here prints the key or the raw body.
"""
import html
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request

_MAX_QUERY = 600
_MAX_WORDS = 75
_MAX_OUT = 4000


def load_key(path=None):
    if path is None:
        home = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
        path = os.path.join(home, "modern", "secrets.json")
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        data = {}
    if not isinstance(data, dict):
        return ""
    brave = data.get("brave")
    if not isinstance(brave, dict):
        return ""
    key = brave.get("apiKey")
    return key.strip() if isinstance(key, str) else ""


def _clip(value, limit):
    text = html.unescape(str(value or ""))
    text = re.sub(r"<[^>]+>", "", text)
    text = " ".join(text.split())
    return text[:limit]


def _items(payload):
    grounding = payload.get("grounding") if isinstance(payload, dict) else None
    if not isinstance(grounding, dict):
        return []
    rows = []
    generic = grounding.get("generic")
    if isinstance(generic, list):
        rows.extend(item for item in generic if isinstance(item, dict))
    poi = grounding.get("poi")
    if isinstance(poi, dict):
        rows.append(poi)
    places = grounding.get("map")
    if isinstance(places, list):
        rows.extend(item for item in places if isinstance(item, dict))
    return rows


def format_results(payload):
    blocks = []
    for row in _items(payload)[:5]:
        title = _clip(row.get("title") or row.get("name"), 160)
        url = _clip(row.get("url"), 200)
        snippets = row.get("snippets")
        if isinstance(snippets, list):
            text = _clip(" ".join(str(part) for part in snippets[:4]), 800)
        else:
            text = ""
        if not title and not text:
            continue
        blocks.append("\n".join(part for part in (title, url, text) if part))
    if not blocks:
        return "No results."
    return "\n\n".join(blocks)[:_MAX_OUT]


def search(query, key, opener=urllib.request.urlopen):
    words = _clip(query, _MAX_QUERY).split()
    text = " ".join(words[:_MAX_WORDS])
    if not text:
        return "Web search needs a query."
    if not key:
        return "Web search is not available."
    url = "https://api.search.brave.com/res/v1/llm/context?" + urllib.parse.urlencode({
        "q": text,
        "count": "10",
        "maximum_number_of_urls": "5",
        "maximum_number_of_tokens": "1024",
        "safesearch": "moderate",
    })
    req = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "X-Subscription-Token": key,
    })
    try:
        with opener(req, timeout=25) as resp:
            raw = resp.read(400000)
    except (OSError, urllib.error.URLError, TimeoutError):
        return "Web search failed."
    try:
        payload = json.loads(raw.decode("utf-8", "replace"))
    except ValueError:
        return "Web search failed."
    return format_results(payload)
