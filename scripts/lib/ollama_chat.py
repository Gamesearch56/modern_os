#!/usr/bin/env python3
"""Stream one Ollama chat, and run web_search without exposing the key.

Ollama's own stream is forwarded as content and thinking lines. A tool
call is answered here, then the chat continues. The key never enters
the request body.
"""
import json
import sys
import time
import urllib.error
import urllib.request

from brave_search import load_key, search

_TOOL = {
    "type": "function",
    "function": {
        "name": "web_search",
        "description": "Search the web. Use this when a fact may have changed or you are unsure.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"},
            },
            "required": ["query"],
        },
    },
}
_MAX_ROUNDS = 2


def _emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _kind(detail, code=0):
    """A short code the shell can translate. Raw runner text stays here."""
    text = str(detail or "").lower()
    try:
        parsed = json.loads(detail) if isinstance(detail, str) else None
    except (TypeError, ValueError):
        parsed = None
    if isinstance(parsed, dict) and parsed.get("error"):
        text = str(parsed["error"]).lower()
    if any(word in text for word in ("out of memory", "oom", "cuda", "unable to allocate")):
        return "memory"
    if "context" in text or "truncat" in text:
        return "context"
    if code == 404:
        return "model"
    return "refused"


def _visible(chunk):
    msg = chunk.get("message") if isinstance(chunk, dict) else None
    if not isinstance(msg, dict):
        return None
    out = {}
    if msg.get("content"):
        out["content"] = msg["content"]
    if msg.get("thinking"):
        out["thinking"] = msg["thinking"]
    if not out:
        return None
    return {"message": out}


def _absorb(calls, incoming):
    if not isinstance(incoming, list):
        return
    for index, call in enumerate(incoming):
        fn = call.get("function") if isinstance(call, dict) else None
        if not isinstance(fn, dict):
            continue
        while len(calls) <= index:
            calls.append({"name": "", "args": {}, "raw": ""})
        name = fn.get("name")
        if isinstance(name, str) and name:
            calls[index]["name"] = name
        args = fn.get("arguments")
        if isinstance(args, dict):
            calls[index]["args"].update(args)
        elif isinstance(args, str) and args:
            calls[index]["raw"] += args


def _query(call):
    args = dict(call.get("args") or {})
    raw = call.get("raw") or ""
    if raw:
        try:
            parsed = json.loads(raw)
        except ValueError:
            parsed = None
        if isinstance(parsed, dict):
            args.update(parsed)
        elif not args:
            return raw.strip()
    for key in ("query", "q"):
        value = args.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _stream(body, deadline, opener):
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/chat",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with opener(req, timeout=30) as resp:
        for line in resp:
            if time.time() > deadline:
                yield {"error": "timeout"}
                return
            text = line.decode("utf-8", "replace").strip()
            if not text:
                continue
            try:
                yield json.loads(text)
            except ValueError:
                continue


def run(body, key, stream_fn, search_fn):
    messages = body.get("messages")
    if not isinstance(messages, list):
        _emit({"error": "bad request"})
        return 1
    for round_i in range(_MAX_ROUNDS + 1):
        use_tools = bool(key) and round_i < _MAX_ROUNDS
        if use_tools:
            body["tools"] = [_TOOL]
        else:
            body.pop("tools", None)
        calls = []
        content = []
        for chunk in stream_fn(body):
            if not isinstance(chunk, dict):
                continue
            if chunk.get("error"):
                err = str(chunk["error"])[:32]
                if err not in ("offline", "timeout", "memory", "context", "model", "refused", "empty"):
                    err = "refused"
                # The shell only learns the reason from this line. Returning
                # without it becomes "could not reply".
                _emit({"error": err})
                return 28 if err == "timeout" else 1
            msg = chunk.get("message") if isinstance(chunk.get("message"), dict) else {}
            if msg.get("content"):
                content.append(str(msg["content"]))
            _absorb(calls, msg.get("tool_calls"))
            visible = _visible(chunk)
            if visible:
                _emit(visible)
            if chunk.get("done"):
                break
        if not use_tools or not calls:
            _emit({"done": True})
            return 0
        _emit({"status": "search"})
        messages.append({
            "role": "assistant",
            "content": "".join(content),
            "tool_calls": [{
                "function": {"name": call["name"] or "web_search", "arguments": call["args"] or {"query": _query(call)}}
            } for call in calls[:3]],
        })
        for call in calls[:3]:
            name = call["name"] or "web_search"
            result = search_fn(_query(call)) if name == "web_search" else "That tool is not available."
            messages.append({"role": "tool", "tool_name": name, "content": result})
        opts = body.get("options")
        if not isinstance(opts, dict):
            opts = {}
            body["options"] = opts
        try:
            ctx = int(opts.get("num_ctx") or 0)
        except (TypeError, ValueError):
            ctx = 0
        opts["num_ctx"] = max(ctx, 4096)
        body["messages"] = messages
    _emit({"done": True})
    return 0


def main(path):
    try:
        with open(path, encoding="utf-8") as handle:
            body = json.load(handle)
    except (OSError, ValueError):
        _emit({"error": "bad request"})
        return 1
    if not isinstance(body, dict):
        _emit({"error": "bad request"})
        return 1
    key = load_key()
    deadline = time.time() + 170

    def stream_fn(payload):
        try:
            yield from _stream(payload, deadline, urllib.request.urlopen)
        except urllib.error.HTTPError as exc:
            detail = ""
            try:
                detail = exc.read().decode("utf-8", "replace")
            except OSError:
                detail = ""
            yield {"error": _kind(detail, exc.code)}
        except TimeoutError:
            yield {"error": "timeout"}
        except (OSError, urllib.error.URLError):
            yield {"error": "offline"}

    def search_fn(query):
        return search(query, key)

    return run(body, key, stream_fn, search_fn)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        _emit({"error": "bad request"})
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
