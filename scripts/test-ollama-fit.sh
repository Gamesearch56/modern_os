#!/usr/bin/env bash
# A small model on a small computer is a good fit. A huge one is not.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIT="$ROOT/scripts/ollama-fit.sh"
MEM="$ROOT/scripts/hw-memory.sh"
MARK="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/FitMark.qml"
FAIL=0
err() { printf 'test-ollama-fit: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-ollama-fit: ok %s\n' "$*"; }

G8=$((8 * 1024 * 1024 * 1024))
G32=$((32 * 1024 * 1024 * 1024))

pair() {
    local ram="$1" vram="$2" name="$3"
    "$FIT" "$ram" "$vram" "$name" | python3 -c 'import json,sys; row=json.load(sys.stdin)[sys.argv[1]]; print(row["level"], row["why"])' "$name"
}

got="$(pair "$G8" 0 qwen3:4b)"
if [ "$got" = "good ram" ]; then
    ok "4b fits an 8 GB computer"
else
    err "4b on 8 GB: $got"
fi

got="$(pair "$G8" 0 qwen3:8b)"
if [ "$got" = "maybe tight" ]; then
    ok "8b is tight on 8 GB"
else
    err "8b on 8 GB: $got"
fi

got="$(pair "$G8" 0 qwen3:14b)"
if [ "$got" = "poor poor" ]; then
    ok "14b does not fit in 8 GB"
else
    err "14b on 8 GB: $got"
fi

got="$(pair "$G32" "$G8" qwen3:8b)"
if [ "$got" = "good gpu" ]; then
    ok "8b fits in 8 GB of graphics memory"
else
    err "8b on 8 GB graphics: $got"
fi

got="$(pair "$G32" "$G8" qwen3:32b)"
if [ "$got" = "maybe spill" ]; then
    ok "32b spills off an 8 GB graphics chip"
else
    err "32b spill: $got"
fi

got="$(pair "$G32" "$G8" qwen3:70b)"
if [ "$got" = "poor poor" ]; then
    ok "70b is too large for 32 GB"
else
    err "70b: $got"
fi

got="$(pair "$G32" 0 phi4-mini)"
if [ "$got" = "unknown unknown" ]; then
    ok "a name without a size stays a guess"
else
    err "unknown size: $got"
fi

if "$MEM" | awk -F '\t' '$1=="ramBytes" && $2+0>0 {found=1} END{exit !found}'; then
    ok "this computer reports installed memory"
else
    err "hw-memory did not report ramBytes"
fi

if grep -Fq 'Colors.fitGood' "$MARK" \
    && grep -Fq 'Colors.fitMaybe' "$MARK" \
    && grep -Fq 'Colors.fitPoor' "$MARK" \
    && grep -Fq 'settings.ollama.fitPoor' "$MARK" \
    && grep -Fq 'FitMark {' "$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections/ai/ModelGroup.qml"; then
    ok "each model row has a fit mark and a reason"
else
    err "fit mark is not wired"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-ollama-fit: all passed\n'
