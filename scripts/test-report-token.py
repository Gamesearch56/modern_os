#!/usr/bin/env python3
"""The sealed bug-report token opens with the matching deploy key only."""
import importlib.util
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
spec = importlib.util.spec_from_file_location(
    "report_token", os.path.join(ROOT, "scripts", "lib", "report-token.py")
)
rt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rt)


def fail(msg):
    print("test-report-token: FAIL %s" % msg, file=sys.stderr)
    sys.exit(1)


def main():
    key = b"-----BEGIN OPENSSH PRIVATE KEY-----\nfake\n"
    blob = rt.seal_bytes("github_pat_testtoken", key)
    if b"github_pat_" in blob or b"testtoken" in blob:
        fail("token is visible in the sealed file")
    if rt.open_bytes(blob, key) != "github_pat_testtoken":
        fail("matching key did not open the token")
    if rt.open_bytes(blob, b"other-key") is not None:
        fail("a different key opened the token")
    data = {"calendar": {"keep": True}, "bugReport": {}}
    data["bugReport"] = {"githubToken": rt.open_bytes(blob, key)}
    if data["calendar"] != {"keep": True}:
        fail("other secrets would be dropped")
    if rt._token_of(data) != "github_pat_testtoken":
        fail("existing token was not read back")
    kept = {"bugReport": {"githubToken": "already"}}
    if rt._token_of(kept) != "already":
        fail("a token already on the machine would be replaced")
    print("test-report-token: all passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
