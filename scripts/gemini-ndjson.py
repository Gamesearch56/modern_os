#!/usr/bin/env python3
# Gemini chat worker: one process so Stop can actually kill it.
# Emits compact {c,e,d} lines; never prints the API key.
import json
import os
import sys
import time
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


def _delay_seconds(raw) -> float | None:
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        return float(raw)
    if isinstance(raw, dict):
        return float(raw.get("seconds") or 0) + float(raw.get("nanos") or 0) / 1e9
    text = str(raw).strip()
    if text.endswith("s"):
        text = text[:-1]
    try:
        return float(text)
    except ValueError:
        return None


def _quota(err: dict) -> tuple:
    parts = []
    delay = None
    for row in err.get("details") or []:
        if not isinstance(row, dict):
            continue
        kind = str(row.get("@type") or "")
        if kind.endswith("QuotaFailure"):
            for hit in row.get("violations") or []:
                if not isinstance(hit, dict):
                    continue
                parts.append(str(hit.get("quotaId") or ""))
                parts.append(str(hit.get("quotaMetric") or ""))
                parts.append(str(hit.get("description") or ""))
        elif kind.endswith("RetryInfo"):
            delay = _delay_seconds(row.get("retryDelay"))
        elif kind.endswith("ErrorInfo"):
            parts.append(str(row.get("reason") or ""))
    return " ".join(parts).lower(), delay


def problem(payload: dict, http_code: int = 0) -> str:
    # Gemini documents string codes (payment_required, quota_exceeded) and
    # the older status plus QuotaFailure details. A daily or prepaid miss
    # does not clear by waiting.
    err = payload.get("error") if isinstance(payload, dict) else None
    if not isinstance(err, dict):
        err = {}
    raw = err.get("code")
    status = str(err.get("status") or "")
    token = raw.lower() if isinstance(raw, str) else status.lower()
    if isinstance(raw, int) and not http_code:
        http_code = raw
    message = str(err.get("message") or "").lower()
    blob, delay = _quota(err)
    text = token + " " + message + " " + blob
    if (
        token == "payment_required"
        or http_code == 402
        or "prepay" in message
        or "credit balance" in message
    ):
        return "credits"
    if "billing" in message and token in ("failed_precondition", "permission_denied"):
        return "credits"
    if any(part in blob for part in ("perday", "per_day", "freetier", "free_tier", "daily")):
        return "credits"
    if token == "quota_exceeded":
        return "credits"
    if "spend" in text:
        return "spend"
    if delay is not None and delay > 60:
        return "credits"
    if token in (
        "rate_limit_exceeded",
        "too_many_requests",
        "resource_exhausted",
        "unavailable",
        "service_unavailable",
    ) or http_code in (429, 500, 503):
        return "rate"
    if token in ("authentication", "unauthenticated", "permission_denied") or http_code in (401, 403):
        return "auth"
    if token in ("not_found", "model_not_found") or status.upper() == "NOT_FOUND" or http_code == 404:
        return "model"
    return "error"


def retry_delay(exc: urllib.error.HTTPError, payload: dict) -> float | None:
    # Only a short Retry-After is worth a second try. A 503 with no delay
    # means the model is busy, and waiting again leaves the chat spinning.
    sec = None
    asked = False
    try:
        hdr = str(exc.headers.get("Retry-After") or "").strip()
        if hdr:
            asked = True
            sec = float(hdr)
    except (AttributeError, TypeError, ValueError):
        sec = None
    err = payload.get("error") if isinstance(payload, dict) else None
    if sec is None and isinstance(err, dict):
        _, delay = _quota(err)
        if delay is not None:
            asked = True
            sec = delay
    if not asked:
        return None
    if sec is None or sec < 0:
        sec = 1.0
    if sec > 8:
        return None
    return sec


def _error_payload(exc: urllib.error.HTTPError) -> dict:
    try:
        payload = json.loads((exc.read() or b"").decode("utf-8", "replace") or "{}")
    except (OSError, json.JSONDecodeError, AttributeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def handle_obj(raw: str) -> None:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return
    err = data.get("error")
    if err:
        code = err.get("code") if isinstance(err, dict) else None
        http = code if isinstance(code, int) else 0
        emit({"e": problem({"error": err if isinstance(err, dict) else {}}, http)})
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


def _read_stream(resp) -> None:
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


def run_chat(model: str, body_path: str, opener=None) -> int:
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
    open_url = opener or urllib.request.urlopen
    # A per-minute limit with a short delay gets one retry. Overload with
    # no delay, and a connection that never answers, stop so the chat does
    # not sit on a spinner for the whole request timeout.
    for attempt in (1, 2):
        try:
            with open_url(req, timeout=40) as resp:
                _read_stream(resp)
            return 0
        except urllib.error.HTTPError as e:
            payload = _error_payload(e)
            kind = problem(payload, e.code)
            wait = retry_delay(e, payload)
            if kind != "rate" or wait is None or attempt == 2:
                emit({"e": kind})
                return 1
            time.sleep(wait)
        except TimeoutError:
            emit({"e": "rate"})
            return 1
        except urllib.error.URLError as e:
            reason = str(getattr(e, "reason", e) or e)
            if "timed out" in reason.lower():
                emit({"e": "rate"})
                return 1
            emit({"e": "error"})
            return 1
        except OSError:
            emit({"e": "error"})
            return 1
    return 1


def run_models(opener=None) -> int:
    key = load_key()
    req = urllib.request.Request(
        "https://generativelanguage.googleapis.com/v1beta/models",
        method="GET",
        headers={
            "Accept": "application/json",
            "Accept-Encoding": "identity",
            "x-goog-api-key": key,
        },
    )
    open_url = opener or urllib.request.urlopen
    try:
        with open_url(req, timeout=15) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace") or "{}")
    except urllib.error.HTTPError as e:
        emit({"error": problem(_error_payload(e), e.code)})
        return 1
    except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError):
        emit({"error": "error"})
        return 1
    if isinstance(payload, dict) and payload.get("error"):
        emit({"error": problem(payload, 0)})
        return 1
    emit(payload if isinstance(payload, dict) else {"models": []})
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
    if len(sys.argv) >= 2 and sys.argv[1] == "models":
        sys.exit(run_models())
    if len(sys.argv) >= 4 and sys.argv[1] == "chat":
        sys.exit(run_chat(sys.argv[2], sys.argv[3]))
    filter_stdin()
