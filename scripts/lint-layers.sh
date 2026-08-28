#!/usr/bin/env bash
# Layer-direction + i18n parity + QML perf lint. Fail-closed: any hit
# exits non-zero so CI and pre-commit catch drift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_ROOT="$ROOT/stow/shell/.config/quickshell/modern"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
FAIL=0

err() { printf 'lint-layers: %s\n' "$*" >&2; FAIL=1; }

# --- qmldir coverage -------------------------------------------------
check_qmldir() {
    local dir="$1"
    local qmldir="$dir/qmldir"
    [ -f "$qmldir" ] || { err "missing $qmldir"; return; }
    while IFS= read -r qml; do
        local base
        base="$(basename "$qml")"
        [ "$base" = "qmldir" ] && continue
        grep -q "$base" "$qmldir" || err "qmldir $(realpath --relative-to="$ROOT" "$qmldir") missing $base"
    done < <(find "$dir" -maxdepth 1 -name '*.qml')
}

check_qmldir "$SHELL_ROOT/Commons"
check_qmldir "$SHELL_ROOT/Services"
check_qmldir "$SHELL_ROOT/Widgets"

# --- layer direction -------------------------------------------------
# Commons must not import Services/Widgets/Modules
if grep -RIn --include='*.qml' -E 'import ["'\'']\.\./(Services|Widgets|Modules)|import qs\.(Services|Widgets|Modules)' "$SHELL_ROOT/Commons" >/dev/null 2>&1; then
    err "Commons imports a lower layer"
    grep -RIn --include='*.qml' -E 'import ["'\'']\.\./(Services|Widgets|Modules)|import qs\.(Services|Widgets|Modules)' "$SHELL_ROOT/Commons" >&2 || true
fi

# Widgets must not import Services or Modules
if grep -RIn --include='*.qml' -E 'import ["'\'']\.\./(Services|Modules)|import qs\.(Services|Modules)|Quickshell\.Io|execDetached|Process ' "$SHELL_ROOT/Widgets" >/dev/null 2>&1; then
    err "Widgets imported Services/Modules or spawned a process"
    grep -RIn --include='*.qml' -E 'import ["'\'']\.\./(Services|Modules)|import qs\.(Services|Modules)|Quickshell\.Io|execDetached|Process ' "$SHELL_ROOT/Widgets" >&2 || true
fi

# Modules must not spawn processes or open files directly
if grep -RIn --include='*.qml' -E 'Quickshell\.execDetached|Process \{|FileView \{' "$SHELL_ROOT/Modules" >/dev/null 2>&1; then
    err "Modules spawned a process or touched a file (must go through Services)"
    grep -RIn --include='*.qml' -E 'Quickshell\.execDetached|Process \{|FileView \{' "$SHELL_ROOT/Modules" >&2 || true
fi

# --- hardcoded tokens ------------------------------------------------
# Hex colors outside Colors.qml / generated files
while IFS= read -r hit; do
    err "hardcoded color: $hit"
done < <(grep -RIn --include='*.qml' -E '#[0-9A-Fa-f]{3,8}' "$SHELL_ROOT" \
    | grep -v '/Commons/Colors.qml' || true)

# Literal millisecond durations in Modules/Widgets (Motion.* is the only source)
while IFS= read -r hit; do
    err "hardcoded duration: $hit"
done < <(grep -RIn --include='*.qml' -E 'duration:\s*[0-9]+' "$SHELL_ROOT/Modules" "$SHELL_ROOT/Widgets" || true)

# --- i18n key parity -------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
    err "jq not on PATH — cannot check i18n parity"
else
    python3 - "$EN" "$DE" <<'PY' || FAIL=1
import json, sys
en = json.load(open(sys.argv[1]))
de = json.load(open(sys.argv[2]))

def keys(obj, prefix=""):
    out = set()
    if isinstance(obj, dict):
        for k, v in obj.items():
            path = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict):
                out |= keys(v, path)
            else:
                out.add(path)
    return out

ke, kd = keys(en), keys(de)
missing_de = sorted(ke - kd)
missing_en = sorted(kd - ke)
if missing_de:
    print("lint-layers: keys in en.json missing from de.json:", file=sys.stderr)
    for k in missing_de:
        print("  ", k, file=sys.stderr)
    sys.exit(1)
if missing_en:
    print("lint-layers: keys in de.json missing from en.json:", file=sys.stderr)
    for k in missing_en:
        print("  ", k, file=sys.stderr)
    sys.exit(1)
PY
fi

if [ "$FAIL" -ne 0 ]; then
    printf 'lint-layers: FAILED\n' >&2
    exit 1
fi
printf 'lint-layers: ok\n'
exit 0
