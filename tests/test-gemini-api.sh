#!/usr/bin/env bash
# Gemini quota errors stay classified. The key is not part of the reply.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-gemini-api: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-gemini-api: ok %s\n' "$*"; }

if python3 - "$ROOT/scripts/gemini-ndjson.py" <<'PY'
import importlib.util
import io
import json
import os
import sys
import urllib.error
from email.message import Message

os.environ["XDG_CONFIG_HOME"] = os.path.join(os.environ.get("TMPDIR", "/tmp"), "modern-gemini-test-config")
os.makedirs(os.environ["XDG_CONFIG_HOME"], exist_ok=True)
os.environ["GEMINI_API_KEY"] = "test-gemini-key"

path = sys.argv[1]
mod_spec = importlib.util.spec_from_file_location("gemini_ndjson", path)
gemini = importlib.util.module_from_spec(mod_spec)
mod_spec.loader.exec_module(gemini)

def http_error(status, payload, retry_after=""):
    hdr = Message()
    if retry_after:
        hdr["Retry-After"] = retry_after
    return urllib.error.HTTPError(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini:streamGenerateContent",
        status,
        "err",
        hdr,
        io.BytesIO(json.dumps(payload).encode("utf-8")),
    )

daily = {
    "error": {
        "code": 429,
        "status": "RESOURCE_EXHAUSTED",
        "message": "You exceeded your current quota, please check your plan and billing details.",
        "details": [{
            "@type": "type.googleapis.com/google.rpc.QuotaFailure",
            "violations": [{
                "quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
                "quotaMetric": "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            }],
        }],
    }
}
if gemini.problem(daily, 429) != "credits":
    raise SystemExit("daily quota")
paid = {"error": {"code": "payment_required", "message": "Prepay credit balance is depleted."}}
if gemini.problem(paid, 402) != "credits":
    raise SystemExit("prepay")
minute = {
    "error": {
        "code": "rate_limit_exceeded",
        "message": "Too many requests.",
        "details": [{"@type": "type.googleapis.com/google.rpc.RetryInfo", "retryDelay": "2s"}],
    }
}
if gemini.problem(minute, 429) != "rate":
    raise SystemExit("per minute")
spend = {"error": {"code": 429, "status": "RESOURCE_EXHAUSTED", "message": "Project spend limit exceeded."}}
if gemini.problem(spend, 429) != "spend":
    raise SystemExit("spend")

class Resp:
    def __init__(self, raw):
        self._raw = raw.encode("utf-8")
    def read(self, _n=None):
        data = self._raw
        self._raw = b""
        return data
    def read1(self, _n=None):
        return self.read()
    def __enter__(self):
        return self
    def __exit__(self, *_a):
        return False

seen = {}
def opener(req, timeout=0):
    seen["url"] = req.full_url
    seen["key"] = req.get_header("X-goog-api-key")
    body = req.data.decode("utf-8") if req.data else ""
    if "test-gemini-key" in body or "test-gemini-key" in seen["url"]:
        raise SystemExit("key leaked into the request target")
    if req.full_url.endswith("/models"):
        return Resp('{"models":[{"name":"models/gemini-2.5-flash","supportedGenerationMethods":["generateContent"]}]}')
    return Resp('data: {"candidates":[{"content":{"parts":[{"text":"Hi"}]},"finishReason":"STOP"}]}\n')

out = []
gemini.emit = lambda obj: out.append(obj)
code = gemini.run_models(opener)
if code != 0 or seen["key"] != "test-gemini-key" or out[-1].get("models", [{}])[0].get("name") != "models/gemini-2.5-flash":
    raise SystemExit("models call")
if "test-gemini-key" in json.dumps(out):
    raise SystemExit("key leaked")

body_path = os.path.join(os.environ["XDG_CONFIG_HOME"], "body.json")
with open(body_path, "w", encoding="utf-8") as f:
    f.write('{"contents":[{"role":"user","parts":[{"text":"Hi"}]}]}')

calls = {"n": 0}
slept = []
gemini.time.sleep = lambda s: slept.append(s)

def limited(req, timeout=0):
    calls["n"] += 1
    if calls["n"] == 1:
        raise http_error(429, minute, "2")
    return Resp('data: {"candidates":[{"content":{"parts":[{"text":"Hi"}]},"finishReason":"STOP"}]}\n')

out.clear()
code = gemini.run_chat("gemini-2.5-flash", body_path, limited)
if code != 0 or calls["n"] != 2 or slept != [2.0]:
    raise SystemExit("rate retry %s %s %s" % (code, calls, slept))
if not any(row.get("c") == "Hi" for row in out):
    raise SystemExit("missing text " + json.dumps(out))

calls["n"] = 0
def broke(req, timeout=0):
    calls["n"] += 1
    raise http_error(402, paid)

out.clear()
code = gemini.run_chat("gemini-2.5-flash", body_path, broke)
if code != 1 or calls["n"] != 1 or out != [{"e": "credits"}]:
    raise SystemExit("credits must not retry " + json.dumps(out))

busy = {"error": {"code": 503, "status": "UNAVAILABLE", "message": "This model is currently experiencing high demand."}}
calls["n"] = 0
def overloaded(req, timeout=0):
    calls["n"] += 1
    raise http_error(503, busy)

out.clear()
code = gemini.run_chat("gemini-3.8-flash", body_path, overloaded)
if code != 1 or calls["n"] != 1 or out != [{"e": "rate"}]:
    raise SystemExit("overload must not retry " + json.dumps(out))
os.remove(body_path)
PY
then
    ok "quota, credits, and one rate retry"
else
    err "gemini errors"
fi

GROUP="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai"
if grep -Fq 'openGeminiBilling' "$ROOT/stow/shell/.config/quickshell/modern/Services/Ai.qml" \
    && grep -Fq 'settings.gemini.addCredits' "$GROUP/Gemini.qml" \
    && grep -Fq 'account.note' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiGemini.qml" \
    && grep -Fq 'aistudio.google.com/billing' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiGeminiAccount.qml" \
    && grep -Fq 'errorGeminiCredits' "$ROOT/stow/modern/.config/modern/translations/en.json" \
    && grep -Fq 'errorGeminiCredits' "$ROOT/stow/modern/.config/modern/translations/de.json"; then
    ok "settings offers gemini billing"
else
    err "settings gemini is not wired"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-gemini-api: all passed\n'
