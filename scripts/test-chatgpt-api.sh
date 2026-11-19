#!/usr/bin/env bash
# ChatGPT requests stay on this machine. The key is not part of the reply.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/lib"
FAIL=0
err() { printf 'test-chatgpt-api: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-chatgpt-api: ok %s\n' "$*"; }

export PYTHONPATH="$LIB${PYTHONPATH:+:$PYTHONPATH}"

if python3 - <<'PY'
import json
import chatgpt_api

names = chatgpt_api.filter_models({"data": [
    {"id": "text-embedding-3-small"},
    {"id": "whisper-1"},
    {"id": "dall-e-3"},
    {"id": "gpt-4o-mini-tts"},
    {"id": "omni-moderation-latest"},
    {"id": "gpt-4o"},
    {"id": "o3-mini"},
    {"id": "gpt-5"},
    {"id": "ft:gpt-4o:private"},
]})
if names[0] != "gpt-5" or "gpt-4o" not in names or "o3-mini" not in names:
    raise SystemExit("model order " + ",".join(names))
for blocked in ("text-embedding-3-small", "whisper-1", "dall-e-3", "gpt-4o-mini-tts", "ft:gpt-4o:private"):
    if blocked in names:
        raise SystemExit("kept " + blocked)

plain = chatgpt_api.request_body("gpt-4o", [{"role": "user", "content": "hi"}], True, True, "Be brief.")
if "reasoning_effort" in plain or plain["max_completion_tokens"] != 4096:
    raise SystemExit("gpt-4o body")
if plain["messages"][0]["role"] != "system":
    raise SystemExit("system role")

think = chatgpt_api.request_body("o3", [{"role": "user", "content": "hi"}], True, False, "Room.")
if think["reasoning_effort"] != "medium" or think["max_completion_tokens"] != 8192:
    raise SystemExit("o3 thinking")
if think["messages"][0]["role"] != "developer":
    raise SystemExit("developer role")

off = chatgpt_api.request_body("gpt-5", [{"role": "user", "content": "hi"}], False, True, "Short.")
if off["reasoning_effort"] != "low":
    raise SystemExit("thinking off")

if chatgpt_api.parse_sse('data: {"choices":[{"delta":{"content":"Hi"}}]}') != {"c": "Hi"}:
    raise SystemExit("delta")
if chatgpt_api.parse_sse("data: [DONE]") != {"d": True}:
    raise SystemExit("done")
PY
then
    ok "models, thinking, and stream lines"
else
    err "library behavior"
fi

if python3 - <<'PY'
import json
import os
import io
import contextlib
import chatgpt_api

os.environ["OPENAI_API_KEY"] = "test-key-not-real"
seen = {}

class Resp:
    def __init__(self, raw):
        self._raw = raw.encode("utf-8")
    def read(self, _n=None):
        data = self._raw
        self._raw = b""
        return data
    def __iter__(self):
        yield b'data: {"choices":[{"delta":{"content":"Hello"}}]}\n'
        yield b"data: [DONE]\n"
    def __enter__(self):
        return self
    def __exit__(self, *_a):
        return False

def opener(req, timeout=0):
    seen["url"] = req.full_url
    seen["auth"] = req.get_header("Authorization")
    body = req.data.decode("utf-8") if req.data else ""
    seen["body"] = body
    if "test-key-not-real" in body or "test-key-not-real" in seen["url"]:
        raise SystemExit("key leaked into the request target")
    if req.full_url.endswith("/models"):
        return Resp('{"data":[{"id":"gpt-4o"},{"id":"whisper-1"}]}')
    return Resp("")

buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    code = chatgpt_api.run_models(opener)
if code != 0 or json.loads(buf.getvalue()).get("models") != ["gpt-4o"] or seen["auth"] != "Bearer test-key-not-real":
    raise SystemExit("models call")
if not seen["url"].endswith("/v1/models"):
    raise SystemExit("models url")

code = None
spec = {"model": "o3", "think": True, "brief": True, "system": "Be brief.", "messages": [{"role": "user", "content": "Hi"}]}
path = "/tmp/modern-chatgpt-test-body.json"
with open(path, "w", encoding="utf-8") as f:
    json.dump(spec, f)
out = []
real_emit = chatgpt_api.emit
chatgpt_api.emit = lambda obj: out.append(obj)
try:
    code = chatgpt_api.run_chat(path, opener)
finally:
    chatgpt_api.emit = real_emit
    os.remove(path)
if code != 0 or out != [{"c": "Hello"}, {"d": True}]:
    raise SystemExit("chat stream " + json.dumps(out))
sent = json.loads(seen["body"])
if sent.get("reasoning_effort") != "medium":
    raise SystemExit("sent effort")
if "test-key-not-real" in json.dumps(out) or "test-key-not-real" in seen["body"]:
    raise SystemExit("key leaked")
PY
then
    ok "key stays on the header"
else
    err "request shape"
fi

GROUP="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai"
if grep -Fq 'value: "chatgpt"' "$GROUP/Section.qml" \
    && grep -Fq 'ChatGpt {' "$GROUP/Section.qml" \
    && grep -Fq 'settings.chatgpt.connect' "$GROUP/ChatGpt.qml" \
    && grep -Fq 'openai.apiKey' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiChatGptAccount.qml" \
    && grep -Fq 'chatgpt-api.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiChatGpt.qml" \
    && grep -Fq 'chatgptModel' "$ROOT/stow/shell/.config/quickshell/modern/Commons/Config.qml"; then
    ok "settings offers a chatgpt account"
else
    err "settings chatgpt is not wired"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-chatgpt-api: all passed\n'
