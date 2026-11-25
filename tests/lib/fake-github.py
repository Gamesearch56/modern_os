#!/usr/bin/env python3
"""Tiny stand-in for the GitHub REST calls report-send.py makes.

Usage: fake-github.py <port-file> <log-file> [refuse|ratelimit|down]

Writes the bound port to <port-file>, appends one JSON line per request
to <log-file>. Contents PUTs succeed once per path (a second PUT without
sha answers 422, like GitHub); issue POSTs return number 7. With
`refuse`, every request answers 401; `ratelimit` answers 403 with
Retry-After (GitHub's secondary rate limit); `down` answers 503.
"""
import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

STORE = {}
BLOBS = {}
ISSUE = {}
BRANCHES = set()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _answer(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _handle(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}") if length else {}
        with open(sys.argv[2], "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"method": self.command, "path": self.path,
                                 "auth": self.headers.get("Authorization", ""), "body": body}) + "\n")
        mode = sys.argv[3] if len(sys.argv) > 3 else ""
        if mode == "refuse":
            return self._answer(401, {"message": "Bad credentials"})
        if mode == "ratelimit":
            self.send_response(403)
            self.send_header("Retry-After", "60")
            self.send_header("Content-Length", "2")
            self.end_headers()
            self.wfile.write(b"{}")
            return None
        if mode == "down":
            return self._answer(503, {"message": "Service Unavailable"})
        if "/git/ref/heads/" in self.path and self.command == "GET":
            name = self.path.split("?", 1)[0].rsplit("/", 1)[-1]
            if name == "main" or name in BRANCHES:
                return self._answer(200, {"object": {"sha": "abc123"}})
            return self._answer(404, {"message": "Not Found"})
        if self.path.endswith("/git/refs") and self.command == "POST":
            ref = str(body.get("ref") or "")
            BRANCHES.add(ref.rsplit("/", 1)[-1])
            return self._answer(201, {"ref": ref, "object": {"sha": body.get("sha", "")}})
        if "/contents/" in self.path:
            if self.command == "GET":
                if "application/vnd.github.raw" in (self.headers.get("Accept") or ""):
                    data = BLOBS.get(self.path)
                    if data is None:
                        return self._answer(404, {"message": "Not Found"})
                    self.send_response(200)
                    self.send_header("Content-Type", "application/octet-stream")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return None
                return self._answer(200, {"sha": STORE.get(self.path, "")})
            if self.path in STORE and not body.get("sha"):
                return self._answer(422, {"message": "sha wasn't supplied"})
            STORE[self.path] = "sha-%d" % len(STORE)
            BLOBS[self.path] = base64.b64decode(body.get("content") or "")
            url = "https://github.test/blob/main/" + self.path.split("/contents/", 1)[1]
            return self._answer(201, {"content": {"html_url": url}})
        if self.path.endswith("/issues") and self.command == "POST":
            ISSUE.clear()
            ISSUE.update(body)
            ISSUE["number"] = 7
            return self._answer(201, {"number": 7, "html_url": "https://github.test/issues/7"})
        if self.command == "GET" and "/issues/" in self.path:
            return self._answer(200, {"number": ISSUE.get("number", 7), "title": ISSUE.get("title", ""), "body": ISSUE.get("body", "")})
        return self._answer(404, {"message": "Not Found"})

    do_GET = _handle
    do_PUT = _handle
    do_POST = _handle


def main():
    server = HTTPServer(("127.0.0.1", 0), Handler)
    with open(sys.argv[1], "w", encoding="utf-8") as fh:
        fh.write(str(server.server_address[1]))
    server.serve_forever()


if __name__ == "__main__":
    main()
