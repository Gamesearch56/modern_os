#!/usr/bin/env python3
"""File a problem report as an issue in the reports repo.

Usage: report-send.py <report-dir> <owner/repo>

Reads request.json (title, description, categories, when, repeat and the
file/shot names the user left ticked), uploads the bundle and the ticked
screenshots with the Contents API, then opens an issue that shows the
screenshots inline and links the bundle. The token is secrets.json →
bugReport.githubToken, scoped to the reports repo only. The `gh` login of
this computer is used only when MODERN_REPORT_GH=1: it usually carries
far more rights than filing one issue needs.

Exit: 0 sent (prints the issue number), 20 unreachable, rate limited or
a GitHub outage (queued, try again later), 21 no token, 22 token refused,
23 any other server answer.
"""
import base64
import io
import json
import os
import re
import socket
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request

API = os.environ.get("BUG_REPORT_API", "https://api.github.com")
LABELS = {
    "display": "area:display", "hyprland": "area:hyprland", "shell": "area:quickshell",
    "sound": "area:audio", "bluetooth": "area:bluetooth", "network": "area:network",
    "games": "area:games", "updates": "area:updates", "lock": "area:session",
    "apps": "area:apps", "other": "area:other",
}
WHEN = {"now": "Just now", "today": "Today", "earlier": "Earlier"}
REPEAT = {"always": "Every time", "sometimes": "Sometimes", "once": "Once"}
EXCERPTS = (
    ("hyprland-log.txt", "Hyprland log (warnings and errors)"),
    ("quickshell-log.txt", "Quickshell log"),
    ("quickshell-journal.txt", "Quickshell journal"),
)
# An update report leads with what the update itself wrote.
UPDATE_EXCERPTS = (
    ("update-log.txt", "Update log"),
    ("update.txt", "Update state"),
)
# Start, login, lock and shutdown: the session chain, then boot.
SESSION_EXCERPTS = (
    ("session.txt", "Session, login and lock"),
    ("boot.txt", "Boot, splash and last shutdown"),
)
# Texteditor, Imageviewer and Mediaplayer run outside the shell process.
APPS_EXCERPTS = (
    ("apps.txt", "ModernOS apps log"),
)


class Unreachable(Exception):
    pass


class Refused(Exception):
    pass


class Rejected(Exception):
    pass


def token():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    try:
        with open(os.path.join(base, "modern", "secrets.json"), encoding="utf-8") as fh:
            saved = str((json.load(fh).get("bugReport") or {}).get("githubToken") or "").strip()
    except (OSError, ValueError, AttributeError):
        saved = ""
    if saved or os.environ.get("MODERN_REPORT_GH") != "1":
        return saved
    try:
        out = subprocess.check_output(["gh", "auth", "token"], stderr=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.decode().strip()


# Worth queueing: the same request can succeed later unchanged.
RETRY = (408, 429, 500, 502, 503, 504)


def _rate_limited(err):
    """GitHub answers secondary rate limits with 403, not 429."""
    headers = err.headers or {}
    return bool(headers.get("Retry-After")) or headers.get("X-RateLimit-Remaining") == "0"


def call(tok, method, path, body):
    req = urllib.request.Request(
        API + path, method=method, data=None if body is None else json.dumps(body).encode(),
        headers={
            "Authorization": "Bearer " + tok,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "modernos-bug-report",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as err:
        if err.code in RETRY or (err.code == 403 and _rate_limited(err)):
            raise Unreachable() from err
        if err.code in (401, 403):
            raise Refused() from err
        raise Rejected(str(err.code)) from err
    except (urllib.error.URLError, socket.timeout, ConnectionError) as err:
        raise Unreachable() from err


def bundle(root, req):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:xz") as tar:
        tar.add(os.path.join(root, "request.json"), arcname="request.json")
        for name in req.get("files") or []:
            path = os.path.join(root, "files", os.path.basename(name))
            if os.path.isfile(path):
                tar.add(path, arcname="files/" + os.path.basename(name))
    return buf.getvalue()


def upload(tok, repo, path, data, message):
    url = "/repos/%s/contents/%s" % (repo, path)
    body = {"message": message, "content": base64.b64encode(data).decode()}
    try:
        resp = call(tok, "PUT", url, body)
    except Rejected as err:
        # A resend after a half-finished upload: overwriting needs the sha.
        if str(err) != "422":
            raise
        body["sha"] = call(tok, "GET", url, None).get("sha", "")
        resp = call(tok, "PUT", url, body)
    return str((resp.get("content") or {}).get("html_url") or "")


def _read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def _facts(text):
    out = {}
    for line in text.splitlines():
        if ": " not in line or line.startswith(("$", "#")):
            continue
        key, val = line.split(": ", 1)
        if " " not in key:
            out.setdefault(key, val.strip())
    return out


def _product(text, prefix):
    for line in text.splitlines():
        if line.startswith(prefix):
            return line.split(" built", 1)[0].split(" (", 1)[0].strip()
    return ""


def _tail(text):
    """Last distinct lines, with terminal colors removed and repeats folded."""
    text = re.sub(r"\x1b\[[0-9;]*m", "", text)
    out, prev, run = [], None, 0
    for ln in text.splitlines():
        if not ln.strip() or ln.startswith("# "):
            continue
        if ln == prev:
            run += 1
            continue
        if prev is not None:
            out.append(prev if run == 1 else "%s  (repeated %d)" % (prev, run))
        prev, run = ln, 1
    if prev is not None:
        out.append(prev if run == 1 else "%s  (repeated %d)" % (prev, run))
    return "\n".join(out[-80:]).replace("```", "'''")[:6000]


def _excerpt(root, req, name, title):
    if name not in (req.get("files") or []):
        return ""
    body = _tail(_read(os.path.join(root, "files", name)))
    if not body.strip():
        return ""
    return "<details>\n<summary>%s</summary>\n\n```text\n%s\n```\n</details>" % (title, body)


def issue_body(root, req, version, bundle_url, shot_urls):
    """One-maintainer issue: steps first, then versions, pictures, log tails."""
    files = os.path.join(root, "files")
    facts = _facts(_read(os.path.join(files, "system.txt")))
    steps = (req.get("description") or "").strip() or "_No steps were written._"
    rows = [
        ("ModernOS", version or "unknown"),
        ("Kernel", facts.get("kernel", "")),
        ("Hyprland", _product(_read(os.path.join(files, "hyprland.txt")), "Hyprland ")),
        ("Quickshell", _product(_read(os.path.join(files, "quickshell.txt")), "quickshell ")
         or _product(_read(os.path.join(files, "quickshell.txt")), "Quickshell ")),
        ("Session", facts.get("session", "")),
        ("When", WHEN.get(req.get("when") or "", req.get("when") or "Just now")),
        ("Happens", REPEAT.get(req.get("repeat") or "", "")),
        ("Areas", ", ".join(req.get("categories") or []) or "other"),
    ]
    lines = ["## Steps", "", steps, "", "## Environment", ""]
    lines.extend("- **%s:** `%s`" % (key, val.replace("`", "'")) for key, val in rows if val)
    lines.append("")
    if shot_urls:
        lines += ["## Screenshots", ""]
        for name, url in shot_urls:
            lines += ["### %s" % name, "", "![%s](%s?raw=true)" % (name, url), ""]
    cats = req.get("categories") or []
    excerpts = ((UPDATE_EXCERPTS if "updates" in cats else ())
                + (SESSION_EXCERPTS if "lock" in cats else ())
                + (APPS_EXCERPTS if "apps" in cats else ()) + EXCERPTS)
    logs = [block for block in (_excerpt(root, req, name, title) for name, title in excerpts) if block]
    if logs:
        lines += ["## Logs", ""] + logs + [""]
    listed = ", ".join("`%s`" % n for n in (req.get("files") or []))
    lines += ["## Bundle", "", "[%s](%s)" % (bundle_url.rsplit("/", 1)[-1], bundle_url), ""]
    if listed:
        lines += ["Included files: %s" % listed, ""]
    lines.append("Fetch: `scripts/report-fetch.sh <issue>`")
    return "\n".join(lines)


def ensure_labels(tok, repo, names):
    """Create a missing area label. An existing one answers 422; keep going."""
    for name in names:
        try:
            call(tok, "POST", "/repos/%s/labels" % repo, {
                "name": name, "color": "6f42c1", "description": name.split(":", 1)[-1],
            })
        except Rejected as err:
            if str(err) != "422":
                print("report-send: label %s not created (%s)" % (name, err), file=sys.stderr)


def version_of(root):
    try:
        with open(os.path.join(root, "files", "system.txt"), encoding="utf-8") as fh:
            facts = dict(l.split(": ", 1) for l in fh.read().splitlines() if ": " in l)
    except OSError:
        return ""
    if facts.get("version"):
        return facts["version"]
    base, commit = facts.get("release-base", ""), facts.get("commit", "")
    return ("%s+%s" % (base, commit)).strip("+")


def send(root, repo, tok):
    done = os.path.join(root, "sent.json")
    if os.path.isfile(done):
        with open(done, encoding="utf-8") as fh:
            return json.load(fh).get("number")
    with open(os.path.join(root, "request.json"), encoding="utf-8") as fh:
        req = json.load(fh)
    rid = os.path.basename(os.path.normpath(root))
    version = version_of(root)
    base = "reports/%s" % rid
    bundle_url = upload(tok, repo, base + "/report.tar.xz", bundle(root, req), "Report %s" % rid)
    shots = []
    for name in req.get("shots") or []:
        path = os.path.join(root, "shots", os.path.basename(name))
        if os.path.isfile(path):
            with open(path, "rb") as fh:
                url = upload(tok, repo, "%s/%s" % (base, os.path.basename(name)), fh.read(), "Report %s screenshot" % rid)
            shots.append((os.path.splitext(os.path.basename(name))[0], url))
    title = (req.get("title") or "").strip() or "Problem report"
    labels = sorted({LABELS.get(c, "area:other") for c in req.get("categories") or ["other"]})
    ensure_labels(tok, repo, labels)
    body = {
        "title": "[%s] %s" % (version or "?", title[:200]),
        "body": issue_body(root, req, version, bundle_url, shots),
        "labels": labels,
    }
    try:
        made = call(tok, "POST", "/repos/%s/issues" % repo, body)
    except Rejected:
        body.pop("labels")
        made = call(tok, "POST", "/repos/%s/issues" % repo, body)
    number = made.get("number")
    # The issue is opened before its number exists, so fill the fetch
    # command in afterwards. A failed edit still leaves a filed issue.
    if number and "<issue>" in body["body"]:
        try:
            call(tok, "PATCH", "/repos/%s/issues/%s" % (repo, number), {
                "body": body["body"].replace("<issue>", str(number)),
            })
        except (Rejected, Unreachable) as err:
            print("report-send: issue %s filed, fetch hint not added (%r)" % (number, err), file=sys.stderr)
    with open(os.path.join(root, "sent.json"), "w", encoding="utf-8") as fh:
        json.dump({"number": number, "url": made.get("html_url", "")}, fh)
    return number


def main():
    if len(sys.argv) != 3 or not os.path.isdir(sys.argv[1]) or "/" not in sys.argv[2]:
        print("usage: report-send.py <report-dir> <owner/repo>", file=sys.stderr)
        return 2
    tok = token()
    if not tok:
        return 21
    try:
        print(send(sys.argv[1], sys.argv[2], tok))
    except Unreachable:
        return 20
    except Refused:
        return 22
    except Rejected as err:
        print("report-send: server answered %s" % err, file=sys.stderr)
        return 23
    return 0


if __name__ == "__main__":
    sys.exit(main())
