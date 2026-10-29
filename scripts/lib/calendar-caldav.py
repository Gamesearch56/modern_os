#!/usr/bin/env python3
"""Fetch VEVENTs from a CalDAV account (Apple iCloud) as one ICS stream."""
from __future__ import annotations

import argparse
import ssl
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from typing import Iterable

DAV = "DAV:"
CAL = "urn:ietf:params:xml:ns:caldav"
NS = {"d": DAV, "c": CAL}
TIMEOUT = 20
DEFAULT_URL = "https://caldav.icloud.com/"


def _text(el: ET.Element | None) -> str:
    if el is None or el.text is None:
        return ""
    return el.text.strip()


def _href(base: str, href: str) -> str:
    if href.startswith("http://") or href.startswith("https://"):
        return href
    if href.startswith("/"):
        from urllib.parse import urlparse

        p = urlparse(base)
        return f"{p.scheme}://{p.netloc}{href}"
    if not base.endswith("/"):
        base += "/"
    return base + href


def _request(url: str, user: str, password: str, method: str, body: str, depth: str) -> bytes:
    req = urllib.request.Request(url, data=body.encode("utf-8"), method=method)
    req.add_header("Depth", depth)
    req.add_header("Content-Type", "application/xml; charset=utf-8")
    pwd = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    pwd.add_password(None, url, user, password)
    https = urllib.request.HTTPSHandler(context=ssl.create_default_context())
    auth = urllib.request.HTTPBasicAuthHandler(pwd)
    opener = urllib.request.build_opener(https, auth)
    with opener.open(req, timeout=TIMEOUT) as resp:
        return resp.read()


def _propfind(url: str, user: str, password: str, body: str, depth: str) -> ET.Element:
    raw = _request(url, user, password, "PROPFIND", body, depth)
    return ET.fromstring(raw)


def _first_href(root: ET.Element, path: str) -> str:
    el = root.find(path, NS)
    if el is None:
        el = root.find(".//" + path.split("/")[-1], NS)
    if el is None:
        return ""
    href = el.find("d:href", NS)
    if href is None:
        href = el.find("{DAV:}href")
    return _text(href)


def principal_url(base: str, user: str, password: str) -> str:
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:">'
        "<d:prop><d:current-user-principal/></d:prop></d:propfind>"
    )
    root = _propfind(base, user, password, body, "0")
    href = _first_href(root, "d:response/d:propstat/d:prop/d:current-user-principal")
    if not href:
        for el in root.iter():
            if el.tag.endswith("href") and el.text:
                return _href(base, el.text.strip())
        raise RuntimeError("no CalDAV principal")
    return _href(base, href)


def calendar_home(principal: str, user: str, password: str) -> str:
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        "<d:prop><c:calendar-home-set/></d:prop></d:propfind>"
    )
    root = _propfind(principal, user, password, body, "0")
    href = _first_href(root, "d:response/d:propstat/d:prop/c:calendar-home-set")
    if not href:
        raise RuntimeError("no calendar home")
    return _href(principal, href)


def _is_calendar(resp: ET.Element) -> bool:
    for el in resp.iter():
        if el.tag.endswith("calendar") and el.tag.endswith("}calendar"):
            return True
        if el.tag == f"{{{CAL}}}calendar":
            return True
    return False


def list_calendars(home: str, user: str, password: str) -> list[str]:
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        "<d:prop><d:resourcetype/><d:displayname/></d:prop></d:propfind>"
    )
    root = _propfind(home, user, password, body, "1")
    out: list[str] = []
    for resp in root.findall("d:response", NS):
        if not _is_calendar(resp):
            continue
        href_el = resp.find("d:href", NS)
        href = _text(href_el)
        if href:
            out.append(_href(home, href))
    return out


def events_ics(cal_url: str, user: str, password: str) -> Iterable[str]:
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        "<d:prop><c:calendar-data/></d:prop>"
        '<c:filter><c:comp-filter name="VCALENDAR">'
        '<c:comp-filter name="VEVENT"/></c:comp-filter></c:filter>'
        "</c:calendar-query>"
    )
    raw = _request(cal_url, user, password, "REPORT", body, "1")
    root = ET.fromstring(raw)
    for el in root.iter():
        if el.tag.endswith("calendar-data") and el.text:
            yield el.text.strip()


def merge(chunks: list[str]) -> str:
    vevents: list[str] = []
    for chunk in chunks:
        start = chunk.find("BEGIN:VEVENT")
        while start >= 0:
            end = chunk.find("END:VEVENT", start)
            if end < 0:
                break
            vevents.append(chunk[start : end + len("END:VEVENT")].strip())
            start = chunk.find("BEGIN:VEVENT", end)
    if not vevents:
        return "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//modern//calendar//EN\nEND:VCALENDAR\n"
    body = "\n".join(vevents)
    return (
        "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//modern//calendar//EN\n"
        f"{body}\nEND:VCALENDAR\n"
    )


def fetch(user: str, password: str, url: str) -> str:
    principal = principal_url(url, user, password)
    home = calendar_home(principal, user, password)
    chunks: list[str] = []
    for cal in list_calendars(home, user, password):
        chunks.extend(events_ics(cal, user, password))
    return merge(chunks)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--user", required=True)
    p.add_argument("--password", required=True)
    p.add_argument("--url", default=DEFAULT_URL)
    args = p.parse_args()
    if not args.user.strip() or not args.password.strip():
        print("calendar-caldav: missing Apple ID or password", file=sys.stderr)
        return 2
    try:
        sys.stdout.write(fetch(args.user.strip(), args.password, args.url))
    except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, ET.ParseError) as e:
        print(f"calendar-caldav: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
