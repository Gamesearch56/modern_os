#!/usr/bin/env bash
# Library search lists families. tags lists every plain size.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/scripts/ollama-library.sh"
QML="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/Library.qml"
GROUP="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/ModelGroup.qml"
SVC="$ROOT/stow/shell/.config/quickshell/modern/Services/AiLibrary.qml"
FAIL=0
err() { printf 'test-ollama-library: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-ollama-library: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-ollama-lib-test-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

cat >"$TMP/search.html" <<'EOF'
<ul role="list">
<li>
  <a href="/library/qwen3">
    <h2><span>qwen3</span></h2>
    <p>Qwen3 is a family of models.</p>
    <span>tools</span>
    <span>thinking</span>
    <span class="text-blue-600">4b</span>
    <span class="text-blue-600">0.6b</span>
  </a>
</li>
<li>
  <a href="/library/../evil">
    <h2><span>evil</span></h2>
    <p>nope</p>
  </a>
</li>
</ul>
EOF
mkdir -p "$TMP/tags"
cat >"$TMP/tags/qwen3.html" <<'EOF'
<a href="/library/qwen3:latest"></a>
<a href="/library/qwen3:0.6b"></a>
<a href="/library/qwen3:4b" class="group-hover:underline">qwen3:4b</a>
<p class="col-span-2 text-neutral-500 text-[13px]">2.5GB</p>
<a href="/library/qwen3:0.6b">qwen3:0.6b</a>
<span>7df6b6e09427</span> • 523MB • 40K
<a href="/library/qwen3:8b"></a>
<a href="/library/qwen3:14b"></a>
<a href="/library/qwen3:32b"></a>
<a href="/library/qwen3:4b-q8_0"></a>
EOF

names() { python3 -c 'import json,sys; print("\n".join(r["name"] for r in json.load(sys.stdin)))'; }

got="$(OLLAMA_LIBRARY_SEARCH_HTML="$TMP/search.html" "$LIB" search qwen | names)"
if [ "$got" = "qwen3" ]; then
    ok "search returns the family"
else
    err "search names: $(printf '%s' "$got" | tr '\n' ' ')"
fi

use="$(OLLAMA_LIBRARY_SEARCH_HTML="$TMP/search.html" "$LIB" search qwen | python3 -c 'import json,sys; r=json.load(sys.stdin)[0]; print(r["use"]+" "+",".join(r["also"])+" "+",".join(r["sizes"]))')"
if [ "$use" = "chat think,tools 0.6b,4b" ]; then
    ok "a family is described by its use and its sizes"
else
    err "use: $use"
fi

python3 - "$ROOT/scripts/lib/ollama_library.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ollama_library", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
checks = {
    ("qwen3-coder", ("tools",)): ("code", ["tools"]),
    ("nomic-embed-text", ("embedding",)): ("embed", []),
    ("gemma3", ("vision",)): ("vision", []),
    ("deepseek-r1", ("tools", "thinking")): ("reason", ["tools"]),
    ("glm-ocr", ()): ("ocr", []),
    ("translategemma", ()): ("translate", []),
    ("dolphin3", ()): ("open", []),
    ("qwen3", ("tools", "thinking")): ("chat", ["think", "tools"]),
}
failed = []
for (name, caps), want in checks.items():
    got = mod.use_case(name, caps)
    if got != want:
        failed.append(f"{name}: {got} != {want}")
plain = mod._row("nomic-embed-text", "", [])
if plain["sizes"] != ["latest"]:
    failed.append("bare family sizes: %s" % plain["sizes"])
if failed:
    sys.exit("\n".join(failed))
PY
ok "use cases follow the model"

sizes="$(OLLAMA_LIBRARY_TAGS_DIR="$TMP/tags" "$LIB" tags qwen3 | names)"
if [ "$sizes" = $'qwen3:0.6b\nqwen3:4b\nqwen3:8b\nqwen3:14b\nqwen3:32b' ]; then
    ok "a family lists every plain size"
else
    err "sizes: $(printf '%s' "$sizes" | tr '\n' ' ')"
fi

disk="$(OLLAMA_LIBRARY_TAGS_DIR="$TMP/tags" "$LIB" tags qwen3 | python3 -c 'import json,sys; rows={r["name"]: r.get("bytes", 0) for r in json.load(sys.stdin)}; print(rows.get("qwen3:4b", 0), rows.get("qwen3:0.6b", 0), rows.get("qwen3:8b", 0))')"
if [ "$disk" = "$((250 * 1024 * 1024 * 1024 / 100)) $((523 * 1024 * 1024)) 0" ]; then
    ok "a size carries its download bytes"
else
    err "disk: $disk"
fi

exact="$(OLLAMA_LIBRARY_SEARCH_HTML="$TMP/search.html" "$LIB" search 'qwen3:32b' | names)"
if printf '%s\n' "$exact" | grep -Fxq 'qwen3:32b'; then
    ok "a typed tag stays on the list"
else
    err "typed tag missing: $(printf '%s' "$exact" | tr '\n' ' ')"
fi

empty="$(OLLAMA_LIBRARY_OFFLINE=1 "$LIB" search | names)"
if printf '%s\n' "$empty" | grep -Fxq 'qwen3'; then
    ok "offline search still offers qwen3"
else
    err "offline search missing qwen3"
fi

index="$(OLLAMA_LIBRARY_INDEX_HTML="$TMP/search.html" "$LIB" search | names)"
if [ "$index" = "qwen3" ]; then
    ok "the library page lists every family on it"
else
    err "index names: $(printf '%s' "$index" | tr '\n' ' ')"
fi

if "$LIB" pull '../evil' >/dev/null 2>&1; then
    err "pull accepted a bad name"
else
    ok "pull rejects a bad name"
fi

dry="$(OLLAMA_LIBRARY_DRY=1 "$LIB" remove 'qwen3:4b')"
progress="$(printf '\033[1Gpulling manifest \033[K\npulling abc: 100%% \033[K\nsuccess \033[K\n' | python3 "$ROOT/scripts/lib/ollama_progress.py")"
if [ "$progress" = $'pulling manifest\npulling abc: 100%\nsuccess' ]; then
    ok "pull progress becomes plain lines"
else
    err "progress: $(printf '%s' "$progress" | tr '\n' '|')"
fi

if [ "$dry" = "remove qwen3:4b" ]; then
    ok "remove prints the checked name"
else
    err "remove dry: $dry"
fi

if grep -Fq 'ollama-library.sh' "$SVC" \
    && grep -Fq 'settings.ollama.installModel' "$GROUP" \
    && grep -Fq 'settings.ollama.deleteModel' "$GROUP" \
    && grep -Fq 'settings.ollama.inUse' "$GROUP" \
    && grep -Fq 'n === cur' "$ROOT/stow/shell/.config/quickshell/modern/Services/AiLibrary.qml" \
    && grep -Fq 'ModelGroup {' "$QML" \
    && grep -Fq 'Library {' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/Section.qml"; then
    ok "settings lists install and delete under the model field"
else
    err "settings library is not wired"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ollama-library: all passed\n'
