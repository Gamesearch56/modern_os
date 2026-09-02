#!/usr/bin/env python3
# Gemini chat worker: one process so Stop can actually kill it.
# Emits compact {c,e,d} lines; never prints the API key.
import json
import os
import sys
import urllib.error
import urllib.request


def drain(buf: str, on_obj) -> str:
    while True:
        s = buf.lstrip(" \t\r\n,[]")
        if s.startswith("data:"):
            s = s[5:].lstrip()
        elif s.startswith("event:"):
            nl = s.find("\n")
            s = "" if nl < 0 else s[nl + 1 :]
            buf = s
            continue
        if not s.startswith("{"):
            return s if s else ""
        depth = 0
        in_str = False
        esc = False
        for i, c in enumerate(s):
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
                continue
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    on_obj(s[: i + 1])
                    buf = s[i + 1 :]
                    break
        else:
            return s
        continue


def emit(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def load_key() -> str:
    xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
        os.environ.get("HOME", ""), ".config"
    )
    key = ""
    path = os.path.join(xdg, "modern", "secrets.json")
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        key = str((data.get("gemini") or {}).get("apiKey") or "").strip()
    except (OSError, json.JSONDecodeError, TypeError):
        key = ""
    if not key:
        key = str(os.environ.get("GEMINI_API_KEY") or "").strip()
    if not key:
        sys.stderr.write("gemini-api: missing key\n")
        sys.exit(2)
    return key


def handle_obj(raw: str) -> None:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return
    err = data.get("error")
    if err:
        msg = str((err or {}).get("message") or (err or {}).get("status") or "error")
        emit({"e": msg[:240]})
        return
    block = ((data.get("promptFeedback") or {}).get("blockReason")) or ""
    if block:
        emit({"e": str(block)[:240]})
        emit({"d": True})
        return
    cands = data.get("candidates") or []
    if not cands:
        return
    c0 = cands[0] or {}
    parts = ((c0.get("content") or {}).get("parts")) or []
    text = ""
    sig = ""
    for p in parts:
        if not p:
            continue
        if p.get("thoughtSignature"):
            sig = str(p.get("thoughtSignature") or "")
        if p.get("thought"):
            continue
        text += str(p.get("text") or "")
    if text:
        row = {"c": text}
        if sig:
            row["s"] = sig
        emit(row)
    reason = str(c0.get("finishReason") or "")
    if reason:
        emit({"d": True})


def run_chat(model: str, body_path: str) -> int:
    try:
        with open(body_path, encoding="utf-8") as f:
            body = f.read()
    except OSError:
        sys.stderr.write("gemini-api: missing body\n")
        return 3
    key = load_key()
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        + model
        + ":streamGenerateContent?alt=sse"
    )
    req = urllib.request.Request(
        url,
        data=body.encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "Accept-Encoding": "identity",
            "x-goog-api-key": key,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            buf = ""
            read1 = resp.read1 if hasattr(resp, "read1") else resp.read
            while True:
                chunk = read1(256)
                if not chunk:
                    break
                buf = drain(buf + chunk.decode("utf-8", "replace"), handle_obj)
            if buf.strip():
                rest = drain(buf, handle_obj)
                tail = rest.strip().strip(",[]")
                if tail.startswith("{"):
                    handle_obj(tail)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        handle_obj(raw if raw.strip().startswith("{") else json.dumps(
            {"error": {"message": f"HTTP {e.code}"}}
        ))
        return 1
    except (TimeoutError, urllib.error.URLError, OSError) as e:
        reason = str(getattr(e, "reason", e) or e)
        if isinstance(e, TimeoutError) or "timed out" in reason.lower():
            return 28
        emit({"e": reason[:240]})
        return 1
    return 0


def filter_stdin() -> None:
    buf = ""
    fd = sys.stdin.fileno()
    while True:
        chunk = os.read(fd, 4096)
        if not chunk:
            break
        buf = drain(
            buf + chunk.decode("utf-8", "replace"),
            lambda raw: (sys.stdout.write(raw + "\n"), sys.stdout.flush()),
        )
    if buf.strip():
        rest = drain(buf, lambda raw: (sys.stdout.write(raw + "\n"), sys.stdout.flush()))
        tail = rest.strip().strip(",[]")
        if tail.startswith("{"):
            sys.stdout.write(tail + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "chat":
        sys.exit(run_chat(sys.argv[2], sys.argv[3]))
    filter_stdin()
