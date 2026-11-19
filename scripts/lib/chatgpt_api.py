# ChatGPT account chat. The key stays in secrets.json and is never printed.
import json
import os
import sys
import urllib.error
import urllib.request


def load_key() -> str:
    xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
        os.environ.get("HOME", ""), ".config"
    )
    key = ""
    path = os.path.join(xdg, "modern", "secrets.json")
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        key = str((data.get("openai") or {}).get("apiKey") or "").strip()
    except (OSError, json.JSONDecodeError, TypeError):
        key = ""
    if not key:
        key = str(os.environ.get("OPENAI_API_KEY") or "").strip()
    return key


def reasons(model: str) -> bool:
    n = str(model or "").lower()
    return n.startswith(("gpt-5", "o1", "o3", "o4"))


def request_body(model: str, messages: list, think: bool, brief: bool, system: str) -> dict:
    # A non-reasoning model rejects reasoning_effort, so it stays off that field.
    role = "developer" if reasons(model) else "system"
    msgs = [{"role": role, "content": str(system or "")}]
    for row in messages or []:
        if not isinstance(row, dict):
            continue
        kind = str(row.get("role") or "")
        if kind not in ("user", "assistant"):
            continue
        text = str(row.get("content") or "").strip()
        if text:
            msgs.append({"role": kind, "content": text})
    body = {
        "model": model,
        "stream": True,
        "messages": msgs,
        "max_completion_tokens": 4096 if brief else 8192,
    }
    if reasons(model):
        body["reasoning_effort"] = "medium" if think else "low"
    return body


def _chat_name(model_id: str) -> bool:
    n = str(model_id or "").lower()
    if not n or n.startswith("ft:"):
        return False
    blocked = (
        "embedding", "whisper", "tts", "dall-e", "moderation",
        "audio", "realtime", "transcribe", "image", "search",
    )
    if any(part in n for part in blocked):
        return False
    return n.startswith(("gpt-", "chatgpt-", "o1", "o3", "o4"))


def _rank(name: str) -> tuple:
    n = name.lower()
    score = 0
    if n.startswith("gpt-5"):
        score = 500
    elif n.startswith("gpt-4.1"):
        score = 410
    elif n.startswith("chatgpt-"):
        score = 420
    elif n.startswith("o4"):
        score = 440
    elif n.startswith("o3"):
        score = 430
    elif n.startswith("gpt-4o"):
        score = 400
    elif n.startswith("gpt-4"):
        score = 390
    elif n.startswith("o1"):
        score = 380
    if "pro" in n:
        score += 5
    if "mini" in n or "nano" in n:
        score -= 3
    if "preview" in n or "-exp" in n:
        score -= 1
    return (score, name)


def filter_models(payload: dict) -> list:
    names = []
    for row in (payload or {}).get("data") or []:
        if not isinstance(row, dict):
            continue
        name = str(row.get("id") or "").strip()
        if _chat_name(name):
            names.append(name)
    names.sort(key=_rank, reverse=True)
    return names


def event_from(data: dict) -> dict | None:
    err = data.get("error")
    if err:
        msg = err.get("message") if isinstance(err, dict) else str(err)
        return {"e": str(msg or "error")[:240]}
    choices = data.get("choices") or []
    if not choices or not isinstance(choices[0], dict):
        return None
    delta = choices[0].get("delta") or {}
    text = str((delta or {}).get("content") or "")
    if text:
        return {"c": text}
    if choices[0].get("finish_reason"):
        return {"d": True}
    return None


def parse_sse(line: str) -> dict | None:
    s = str(line or "").strip()
    if not s.startswith("data:"):
        return None
    s = s[5:].strip()
    if s == "[DONE]":
        return {"d": True}
    try:
        data = json.loads(s)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict):
        return None
    return event_from(data)


def emit(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _auth_header(key: str) -> dict:
    return {
        "Authorization": "Bearer " + key,
        "Accept": "application/json",
        "Accept-Encoding": "identity",
    }


def run_models(opener=None) -> int:
    key = load_key()
    if not key:
        sys.stderr.write("chatgpt-api: missing key\n")
        return 2
    req = urllib.request.Request(
        "https://api.openai.com/v1/models",
        method="GET",
        headers=_auth_header(key),
    )
    open_url = opener or urllib.request.urlopen
    try:
        with open_url(req, timeout=20) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace") or "{}")
    except urllib.error.HTTPError as e:
        emit({"error": f"HTTP {e.code}"})
        return 1
    except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError):
        emit({"error": "unreachable"})
        return 1
    if isinstance(payload, dict) and payload.get("error"):
        emit({"error": "auth"})
        return 1
    emit({"models": filter_models(payload if isinstance(payload, dict) else {})})
    return 0


def run_chat(path: str, opener=None) -> int:
    try:
        with open(path, encoding="utf-8") as f:
            spec = json.load(f)
    except (OSError, json.JSONDecodeError):
        sys.stderr.write("chatgpt-api: missing body\n")
        return 3
    if not isinstance(spec, dict):
        return 3
    key = load_key()
    if not key:
        sys.stderr.write("chatgpt-api: missing key\n")
        return 2
    model = str(spec.get("model") or "")
    brief = spec.get("brief") is not False
    api = request_body(
        model,
        spec.get("messages") or [],
        spec.get("think") is True,
        brief,
        str(spec.get("system") or ""),
    )
    raw = json.dumps(api).encode("utf-8")
    headers = _auth_header(key)
    headers["Content-Type"] = "application/json"
    headers["Accept"] = "text/event-stream"
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=raw,
        method="POST",
        headers=headers,
    )
    open_url = opener or urllib.request.urlopen
    try:
        with open_url(req, timeout=180) as resp:
            for chunk in resp:
                ev = parse_sse(chunk.decode("utf-8", "replace"))
                if ev:
                    emit(ev)
    except urllib.error.HTTPError as e:
        emit({"e": f"HTTP {e.code}"})
        return 1
    except TimeoutError:
        return 28
    except urllib.error.URLError as e:
        reason = str(getattr(e, "reason", e) or e)
        if "timed out" in reason.lower():
            return 28
        emit({"e": "unreachable"})
        return 1
    except OSError:
        emit({"e": "unreachable"})
        return 1
    return 0


def main(argv: list) -> int:
    if len(argv) >= 2 and argv[1] == "models":
        return run_models()
    if len(argv) >= 3 and argv[1] == "chat":
        return run_chat(argv[2])
    sys.stderr.write("chatgpt-api: usage\n")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
