#!/usr/bin/env python3
"""Fetch VEVENTs from a CalDAV account (Apple iCloud) as one ICS stream.

The password comes from $CALDAV_PASSWORD, never argv. Exit codes match
calendar-fetch.sh: 10 credentials refused, 12 server unreachable.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import os
import re
import socket
import ssl
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from typing import Iterable
from urllib.parse import urljoin

DAV = "DAV:"
CAL = "urn:ietf:params:xml:ns:caldav"
NS = {"d": DAV, "c": CAL}
TIMEOUT = 20
DEFAULT_URL = "https://caldav.icloud.com/"
EXIT_AUTH = 10
EXIT_OFFLINE = 12
# The popup pages month by month; a bounded window keeps iCloud from
# returning every event ever stored.
PAST_DAYS = 366
FUTURE_DAYS = 2 * 366


class AuthRefused(Exception):
    pass


class _KeepMethod(urllib.request.HTTPRedirectHandler):
    """iCloud moves accounts to a pNN-caldav host; PROPFIND/REPORT must
    follow with method, body and credentials intact."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if code not in (301, 302, 307, 308):
            return None
        new = urllib.request.Request(newurl, data=req.data, method=req.get_method())
        for k, v in req.header_items():
            new.add_header(k, v)
        return new


def _text(el: ET.Element | None) -> str:
    if el is None or el.text is None:
        return ""
    return el.text.strip()


def _request(url: str, auth: str, method: str, body: str, depth: str) -> bytes:
    req = urllib.request.Request(url, data=body.encode("utf-8"), method=method)
    req.add_header("Depth", depth)
    req.add_header("Content-Type", "application/xml; charset=utf-8")
    req.add_header("Authorization", auth)
    opener = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=ssl.create_default_context()), _KeepMethod()
    )
    try:
        with opener.open(req, timeout=TIMEOUT) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            raise AuthRefused() from e
        raise


def _propfind(url: str, auth: str, prop: str, depth: str) -> ET.Element:
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        f"<d:prop>{prop}</d:prop></d:propfind>"
    )
    return ET.fromstring(_request(url, auth, "PROPFIND", body, depth))


def _prop_href(root: ET.Element, tag: str) -> str:
    for el in root.iter(tag):
        href = el.find("{DAV:}href")
        if href is not None and _text(href):
            return _text(href)
    return ""


def principal_url(base: str, auth: str) -> str:
    root = _propfind(base, auth, "<d:current-user-principal/>", "0")
    href = _prop_href(root, "{DAV:}current-user-principal")
    if not href:
        raise RuntimeError("no CalDAV principal")
    return urljoin(base, href)


def calendar_home(principal: str, auth: str) -> str:
    root = _propfind(principal, auth, "<c:calendar-home-set/>", "0")
    href = _prop_href(root, f"{{{CAL}}}calendar-home-set")
    if not href:
        raise RuntimeError("no calendar home")
    return urljoin(principal, href)


def list_calendars(home: str, auth: str) -> list[str]:
    root = _propfind(home, auth, "<d:resourcetype/>", "1")
    out: list[str] = []
    for resp in root.findall("d:response", NS):
        kinds = resp.find(".//d:resourcetype", NS)
        if kinds is None or kinds.find(f"{{{CAL}}}calendar") is None:
            continue
        href = _text(resp.find("d:href", NS))
        if href:
            out.append(urljoin(home, href))
    return out


def _stamp(t: dt.datetime) -> str:
    return t.strftime("%Y%m%dT%H%M%SZ")


def events_ics(cal_url: str, auth: str, now: dt.datetime) -> Iterable[str]:
    start = _stamp(now - dt.timedelta(days=PAST_DAYS))
    end = _stamp(now + dt.timedelta(days=FUTURE_DAYS))
    body = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        "<d:prop><c:calendar-data/></d:prop>"
        '<c:filter><c:comp-filter name="VCALENDAR">'
        f'<c:comp-filter name="VEVENT"><c:time-range start="{start}" end="{end}"/>'
        "</c:comp-filter></c:comp-filter></c:filter>"
        "</c:calendar-query>"
    )
    root = ET.fromstring(_request(cal_url, auth, "REPORT", body, "1"))
    for el in root.iter(f"{{{CAL}}}calendar-data"):
        if el.text:
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
    body = "".join(v + "\n" for v in vevents)
    return f"BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//modern//calendar//EN\n{body}END:VCALENDAR\n"


def fetch(user: str, password: str, url: str) -> str:
    token = base64.b64encode(f"{user}:{password}".encode()).decode("ascii")
    auth = f"Basic {token}"
    home = calendar_home(principal_url(url, auth), auth)
    now = dt.datetime.now(dt.timezone.utc)
    chunks: list[str] = []
    for cal in list_calendars(home, auth):
        # Reminders lists are calendars too and may refuse a VEVENT
        # query; one refusal must not hide every other calendar.
        try:
            chunks.extend(events_ics(cal, auth, now))
        except (AuthRefused, urllib.error.HTTPError, ET.ParseError):
            continue
    return merge(chunks)


def app_password(raw: str) -> str:
    """Apple shows app passwords as abcd-efgh-ijkl-mnop; copies arrive with
    spaces, no dashes or in capitals. Anything else is passed through."""
    letters = re.sub(r"[\s-]", "", raw)
    if re.fullmatch(r"[A-Za-z]{16}", letters):
        letters = letters.lower()
        return "-".join(letters[i : i + 4] for i in range(0, 16, 4))
    return raw.strip()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--user", required=True)
    p.add_argument("--url", default=DEFAULT_URL)
    args = p.parse_args()
    user = args.user.strip()
    password = app_password(os.environ.get("CALDAV_PASSWORD", ""))
    if not user or not password:
        print("calendar-caldav: missing Apple ID or password", file=sys.stderr)
        return EXIT_AUTH
    try:
        sys.stdout.write(fetch(user, password, args.url))
    except AuthRefused:
        print("calendar-caldav: credentials refused", file=sys.stderr)
        return EXIT_AUTH
    except (urllib.error.URLError, socket.timeout, TimeoutError) as e:
        if isinstance(e, urllib.error.HTTPError):
            print(f"calendar-caldav: HTTP {e.code}", file=sys.stderr)
            return 1
        print("calendar-caldav: server unreachable", file=sys.stderr)
        return EXIT_OFFLINE
    except (RuntimeError, ET.ParseError) as e:
        print(f"calendar-caldav: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
