#!/usr/bin/env python3
"""iCloud-shaped CalDAV stub for scripts/test-calendar-fetch.sh.

Prints its port, then serves until killed. Mirrors what the real server
does to clients: two WWW-Authenticate challenges, a redirect to the
account's partition, a Reminders list that refuses VEVENT queries and an
inbox that is not a calendar.
"""
from __future__ import annotations

import base64
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USER, PASSWORD = sys.argv[1], sys.argv[2]
GOOD = "Basic " + base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()

MS = '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">{}</d:multistatus>'


def response(href: str, prop: str) -> str:
    return f"<d:response><d:href>{href}</d:href><d:propstat><d:prop>{prop}</d:prop></d:propstat></d:response>"


EVENT = (
    "BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:icloud-1\nSUMMARY:Dentist\n"
    "DTSTART:20261103T090000Z\nDTEND:20261103T100000Z\nEND:VEVENT\nEND:VCALENDAR\n"
)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code: int, body: str = "", headers: list[tuple[str, str]] | None = None):
        data = body.encode()
        self.send_response(code)
        for k, v in headers or []:
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _dav(self):
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        if self.headers.get("Authorization") != GOOD:
            return self._send(401, headers=[
                ("WWW-Authenticate", 'Basic realm="MMCalDav"'),
                ("WWW-Authenticate", 'X-MobileMe-AuthToken realm="MMCalDav"'),
            ])
        p = self.path
        if p == "/":
            return self._send(301, headers=[("Location", "/p36/")])
        if p == "/p36/":
            return self._send(207, MS.format(response(p, "<d:current-user-principal><d:href>/p36/123/principal/</d:href></d:current-user-principal>")))
        if p == "/p36/123/principal/":
            return self._send(207, MS.format(response(p, "<c:calendar-home-set><d:href>/p36/123/calendars/</d:href></c:calendar-home-set>")))
        if p == "/p36/123/calendars/" and self.command == "PROPFIND":
            return self._send(207, MS.format(
                response(p, "<d:resourcetype><d:collection/></d:resourcetype>")
                + response(p + "home/", "<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>")
                + response(p + "tasks/", "<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>")
                + response(p + "inbox/", "<d:resourcetype><d:collection/><c:schedule-inbox/></d:resourcetype>")
            ))
        if p.endswith("/tasks/"):
            return self._send(403)
        if p.endswith("/home/") and self.command == "REPORT":
            return self._send(207, MS.format(response(p + "1.ics", f"<c:calendar-data>{EVENT}</c:calendar-data>")))
        return self._send(404)

    do_PROPFIND = _dav
    do_REPORT = _dav


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
