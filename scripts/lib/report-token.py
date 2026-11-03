#!/usr/bin/env python3
"""Carry the bug-report token with the desktop without writing it in the clear.

`seal` locks the token from secrets.json to the update deploy key and
writes install/share/bug-report.token. `install` opens that file with the
same key and fills bugReport.githubToken when the account does not have
one yet. Other secrets.json entries are left as they are.

The token is never printed.
"""
import hashlib
import hmac
import json
import os
import sys

MAGIC = b"mrt1"
NONCE = 16
MAC = 32


def _die(msg):
    print("report-token: %s" % msg, file=sys.stderr)
    return 1


def _keystream(key, nonce, n):
    out = b""
    counter = 0
    while len(out) < n:
        out += hmac.new(key, b"ks\0" + nonce + counter.to_bytes(4, "big"), hashlib.sha256).digest()
        counter += 1
    return out[:n]


def _material(raw):
    return hashlib.sha256(b"modernos-report-token-v1\0" + raw).digest()


def seal_bytes(token, key_raw):
    key = _material(key_raw)
    nonce = os.urandom(NONCE)
    body = token.encode()
    stream = _keystream(key, nonce, len(body))
    ct = bytes(a ^ b for a, b in zip(body, stream))
    mac = hmac.new(key, b"mac\0" + nonce + ct, hashlib.sha256).digest()
    return MAGIC + nonce + mac + ct


def open_bytes(blob, key_raw):
    if len(blob) < len(MAGIC) + NONCE + MAC or not blob.startswith(MAGIC):
        return None
    nonce = blob[len(MAGIC):len(MAGIC) + NONCE]
    mac = blob[len(MAGIC) + NONCE:len(MAGIC) + NONCE + MAC]
    ct = blob[len(MAGIC) + NONCE + MAC:]
    key = _material(key_raw)
    expect = hmac.new(key, b"mac\0" + nonce + ct, hashlib.sha256).digest()
    if not hmac.compare_digest(mac, expect):
        return None
    stream = _keystream(key, nonce, len(ct))
    return bytes(a ^ b for a, b in zip(ct, stream)).decode()


def _read(path):
    with open(path, "rb") as fh:
        return fh.read()


def _repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _key_paths(root):
    home = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    found = []
    for path in (
        os.path.join(root, "secrets", "github-deploy-key"),
        os.path.join(home, "modern", "deploy_key"),
    ):
        if os.path.isfile(path) and not os.path.islink(path):
            found.append(path)
    return found


def _secrets_path(home):
    return os.path.join(home, ".config", "modern", "secrets.json")


def _load_secrets(path):
    if not os.path.isfile(path):
        return {}
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("secrets.json is not an object")
    return data


def _token_of(data):
    bug = data.get("bugReport")
    if not isinstance(bug, dict):
        return ""
    return str(bug.get("githubToken") or "").strip()


def cmd_seal(root):
    keys = _key_paths(root)
    if not keys:
        return _die("no deploy key to seal with")
    key = keys[0]
    secrets = _load_secrets(_secrets_path(os.path.expanduser("~")))
    token = _token_of(secrets)
    if not token:
        return _die("no bug-report token to seal")
    dest = os.path.join(root, "install", "share", "bug-report.token")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    blob = seal_bytes(token, _read(key))
    tmp = dest + ".tmp"
    with open(tmp, "wb") as fh:
        fh.write(blob)
    os.chmod(tmp, 0o644)
    os.replace(tmp, dest)
    print("report-token: sealed")
    return 0


def cmd_install(root, home):
    src = os.path.join(root, "install", "share", "bug-report.token")
    if not os.path.isfile(src):
        return 0
    blob = _read(src)
    token = ""
    for key in _key_paths(root):
        token = open_bytes(blob, _read(key)) or ""
        if token:
            break
    if not token:
        return _die("sealed token does not open with this deploy key")
    path = _secrets_path(home)
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    try:
        data = _load_secrets(path)
    except (OSError, ValueError, json.JSONDecodeError):
        return _die("secrets.json could not be read")
    if _token_of(data):
        print("report-token: already set")
        return 0
    bug = data.get("bugReport")
    if not isinstance(bug, dict):
        bug = {}
    bug["githubToken"] = token
    data["bugReport"] = bug
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
    os.chmod(path, 0o600)
    print("report-token: installed")
    return 0


def main():
    root = _repo_root()
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "seal":
        return cmd_seal(root)
    if cmd == "install":
        home = os.path.expanduser("~")
        if len(sys.argv) > 2:
            home = sys.argv[2]
        return cmd_install(root, home)
    return _die("usage: report-token.py seal|install [home]")


if __name__ == "__main__":
    sys.exit(main())
