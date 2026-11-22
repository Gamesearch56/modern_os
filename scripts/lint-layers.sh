#!/usr/bin/env bash
# Layer-direction + i18n parity + QML perf lint. Fail-closed: any hit
# exits non-zero so CI and pre-commit catch drift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_ROOT="$ROOT/stow/shell/.config/quickshell/modern"
TRANSLATIONS="$ROOT/stow/modern/.config/modern/translations"
EN="$TRANSLATIONS/en.json"
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
# Every translations/<lang>.json carries exactly en.json's keys and the
# same %1 / {name} placeholders, and every language has a catalog entry
# (languages.json) that the installer can turn into a locale + keyboard.
if ! command -v jq >/dev/null 2>&1; then
    err "jq not on PATH — cannot check i18n parity"
else
    python3 - "$TRANSLATIONS" <<'PY' || FAIL=1
import json, re, sys
from pathlib import Path

tdir = Path(sys.argv[1])
PLACEHOLDER = re.compile(r"%\d|\{[A-Za-z_][A-Za-z0-9_]*\}")


def flat(obj, prefix=""):
    out = {}
    for k, v in obj.items():
        path = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            out.update(flat(v, path))
        else:
            out[path] = v
    return out


en = flat(json.loads((tdir / "en.json").read_text(encoding="utf-8")))
bad = False
for path in sorted(tdir.glob("*.json")):
    if path.stem == "en":
        continue
    other = flat(json.loads(path.read_text(encoding="utf-8")))
    for label, keys in (
        (f"keys in en.json missing from {path.name}", sorted(set(en) - set(other))),
        (f"keys in {path.name} missing from en.json", sorted(set(other) - set(en))),
        (
            f"{path.name} changes the %1 / {{name}} placeholders of",
            sorted(
                k for k in set(en) & set(other)
                if isinstance(en[k], str) and isinstance(other[k], str)
                and sorted(PLACEHOLDER.findall(en[k])) != sorted(PLACEHOLDER.findall(other[k]))
            ),
        ),
    ):
        if keys:
            bad = True
            print(f"lint-layers: {label}:", file=sys.stderr)
            for k in keys:
                print("  ", k, file=sys.stderr)
for lang in sorted(p.stem for p in tdir.glob("*.json")):
    if f"settings.langs.{lang}" not in en:
        bad = True
        print(f"lint-layers: en.json has no settings.langs.{lang} (language name for Settings)", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
fi
python3 "$ROOT/scripts/installer-locales.py" --check >/dev/null || err "languages.json / keyboard-layouts.json invalid (scripts/installer-locales.py --check)"

# --- file size (Config.qml is a JsonAdapter; do not size-fail it) ---
MAX_LINES=290
while IFS= read -r qml; do
    base="$(basename "$qml")"
    # JsonAdapter blob; IPC facade composes HyprMonitors/HyprWindows;
    # NotificationServer + toast list stay in one singleton.
    case "$base" in
        Config.qml|Hypr.qml|Notifications.qml|Colors.qml) continue ;;
    esac
    n="$(wc -l < "$qml")"
    if [ "$n" -gt "$MAX_LINES" ]; then
        err "file too long ($n > $MAX_LINES): $(realpath --relative-to="$ROOT" "$qml")"
    fi
done < <(find "$SHELL_ROOT" -name '*.qml' ! -path '*/Colors.qml')

# --- module-internal imports (a Module may only use another Module's Module.qml) ---
while IFS= read -r hit; do
    err "module imported another module's internals: $hit"
done < <(grep -RIn --include='*.qml' -E 'import ["'\'']\.\./(Bar|Settings|Launcher|Notifications|Wallpaper|PowerMenu|Cheatsheet|Overview|Session|Plugins|Onboarding|FilePreview|Screenshot|Store)/' "$SHELL_ROOT/Modules" \
    | grep -v 'Module.qml' || true)

# --- hardcoded repo scripts path (must go through Commons/Paths.qml) ---
while IFS= read -r hit; do
    err "hardcoded modern_dotfile/scripts (use Paths): $hit"
done < <(grep -RIn --include='*.qml' 'modern_dotfile/scripts' "$SHELL_ROOT" \
    | grep -v '/Commons/Paths.qml' || true)

# --- Config.qml defaults vs config.default.json (var blobs are not deep-merged) ---
DEFAULT_JSON="$ROOT/stow/modern/.config/modern/config.default.json"
CONFIG_QML="$SHELL_ROOT/Commons/Config.qml"
if [ -f "$DEFAULT_JSON" ] && [ -f "$CONFIG_QML" ]; then
    python3 - "$DEFAULT_JSON" "$CONFIG_QML" <<'PY' || FAIL=1
import json, re, sys
default = json.load(open(sys.argv[1]))
qml = open(sys.argv[2]).read()
fail = False

def miss(msg):
    global fail
    print("lint-layers:", msg, file=sys.stderr)
    fail = True

uis = re.findall(r'property string ui:\s*"([^"]+)"', qml)
lang_ui = uis[-1] if uis else None
if lang_ui and default.get("language", {}).get("ui") != lang_ui:
    miss(f"language.ui Config.qml={lang_ui!r} default.json={default.get('language', {}).get('ui')!r}")

binds = default.get("keybinds") or {}
for k in binds:
    if k.startswith("_"):
        continue
    if not re.search(r'\b' + re.escape(k) + r'\s*:', qml):
        miss(f"keybinds.{k} in default.json missing from Config.qml")

if fail:
    sys.exit(1)
PY
fi

# --- referenced i18n keys exist in en.json ---
if command -v python3 >/dev/null 2>&1 && [ -f "$EN" ]; then
    python3 - "$EN" "$SHELL_ROOT" <<'PY' || FAIL=1
import json, re, sys
from pathlib import Path
en = json.load(open(sys.argv[1]))

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
known = keys(en)
root = Path(sys.argv[2])
pat = re.compile(r'''(?:I18n\.t\(|(?:titleKey|hintKey|labelKey|placeholderKey|emptyKey|key|bodyKey|confirmKey|cancelKey|destructiveKey|actionKey|subtitleKey)\s*:\s*)["']([a-zA-Z][a-zA-Z0-9.]+)["']''')
missing = set()
for qml in root.rglob("*.qml"):
    text = qml.read_text(errors="replace")
    for m in pat.finditer(text):
        k = m.group(1)
        if k not in known and "." in k and not k.endswith("."):
            missing.add(k)
if missing:
    print("lint-layers: I18n keys used in QML missing from en.json:", file=sys.stderr)
    for k in sorted(missing):
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
