#!/usr/bin/env bash
# Web search stays in the shell. The key is not part of the reply.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/lib"
FAIL=0
err() { printf 'test-brave-search: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-brave-search: ok %s\n' "$*"; }

export PYTHONPATH="$LIB${PYTHONPATH:+:$PYTHONPATH}"

if python3 - <<'PY'
import json
import brave_search
import ollama_chat

payload = {"grounding": {"generic": [
    {"title": "Example", "url": "https://example.com/a", "snippets": ["A current fact."]},
    {"title": "Other", "url": "https://example.com/b", "snippets": ["More."]},
]}}
text = brave_search.format_results(payload)
if "Example" not in text or "https://example.com/a" not in text:
    raise SystemExit("format missed a result")
if brave_search.format_results({}) != "No results.":
    raise SystemExit("empty format")

seen = {}

class Resp:
    def __init__(self, raw):
        self._raw = raw
    def read(self, _n):
        return self._raw
    def __enter__(self):
        return self
    def __exit__(self, *_a):
        return False

def opener(req, timeout=0):
    seen["header"] = req.get_header("X-subscription-token")
    seen["url"] = req.full_url
    return Resp(json.dumps(payload).encode())

got = brave_search.search("qwen", "test-key-not-real", opener)
if got != text:
    raise SystemExit("search did not format the body")
if seen.get("header") != "test-key-not-real":
    raise SystemExit("key was not sent as a header")
if "test-key-not-real" in got or "test-key-not-real" in seen.get("url", ""):
    raise SystemExit("key leaked into the query or the result")
if "/res/v1/llm/context?" not in seen.get("url", "") or "maximum_number_of_tokens=1024" not in seen.get("url", ""):
    raise SystemExit("not the llm context endpoint")
if brave_search.search("   ", "test-key-not-real", opener) != "Web search needs a query.":
    raise SystemExit("blank query")
if brave_search.search("qwen", "", opener) != "Web search is not available.":
    raise SystemExit("missing key")

out = []
real_emit = ollama_chat._emit
ollama_chat._emit = lambda obj: out.append(obj)
calls = {"n": 0}

def stream_fn(body):
    calls["n"] += 1
    if calls["n"] == 1:
        yield {"message": {"role": "assistant", "content": "", "tool_calls": [
            {"function": {"name": "web_search", "arguments": {"query": "current news"}}}
        ]}, "done": True}
        return
    tools = [m for m in body.get("messages", []) if m.get("role") == "tool"]
    if not tools or "Example" not in tools[0].get("content", ""):
        raise SystemExit("tool result was not sent back")
    if "test-key-not-real" in json.dumps(body):
        raise SystemExit("key leaked into the follow-up request")
    yield {"message": {"role": "assistant", "content": "Here is the answer."}, "done": True}

def search_fn(query):
    if query != "current news":
        raise SystemExit("bad query %r" % query)
    return text

code = ollama_chat.run(
    {"model": "qwen3:4b", "messages": [{"role": "user", "content": "What is new?"}]},
    "test-key-not-real",
    stream_fn,
    search_fn,
)
ollama_chat._emit = real_emit
blob = json.dumps(out)
if code != 0 or "Here is the answer." not in blob or "test-key-not-real" in blob:
    raise SystemExit("loop code=%s out=%s" % (code, blob))
if not any(obj.get("done") is True for obj in out):
    raise SystemExit("missing done")
PY
then
    ok "a search result reaches the model and the key stays out of it"
else
    err "search loop"
fi

if grep -Fq 'ollama-chat.sh' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiChat.qml" \
    && grep -Fq 'web_search' "$ROOT/stow/modern/.config/modern/translations/en.json" \
    && grep -Fq 'web_search' "$ROOT/stow/modern/.config/modern/translations/de.json" \
    && grep -Fq 'BraveKey {' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/Section.qml" \
    && grep -Fq 'brave.apiKey' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiSearch.qml" \
    && grep -Fq 'api-dashboard.search.brave.com/app/keys' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiSearch.qml" \
    && grep -Fq 'settings.brave.getKey' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/BraveKey.qml"; then
    ok "the assistant asks the model to search"
else
    err "assistant search is not wired"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-brave-search: all passed\n'
