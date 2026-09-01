#!/usr/bin/env bash
# Catalog / config contract: every Settings page in Catalog.qml exists
# on disk, in i18n, and restore paths exist in config.default.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/Catalog.qml"
SECTIONS="$ROOT/stow/shell/.config/quickshell/modern/Modules/Settings/sections"
DEFAULT="$ROOT/stow/modern/.config/modern/config.default.json"
EN="$ROOT/stow/modern/.config/modern/translations/en.json"
DE="$ROOT/stow/modern/.config/modern/translations/de.json"
SET="$ROOT/scripts/config-set.sh"
RESTORE="$ROOT/scripts/config-restore.sh"
FAIL=0

err() { printf 'test-settings-catalog: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-settings-catalog: ok %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }

mapfile -t IDS < <(python3 - "$CATALOG" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
block = re.search(r"readonly property var ids:\s*\[(.*?)\]", text, re.S)
if not block:
    raise SystemExit("no ids array")
ids = re.findall(r'"([^"]+)"', block.group(1))
print("\n".join(ids))
PY
)

if [ "${#IDS[@]}" -ne 21 ]; then
    err "Catalog.qml ids count is ${#IDS[@]} (expected 21)"
else
    ok "21 catalog ids"
fi

SKIP_MUTATE="network bluetooth audio"

has_path() {
    local path="$1"
    jq -e --arg p "$path" 'getpath($p | split(".")) != null' "$DEFAULT" >/dev/null
}

while IFS= read -r id; do
    [ -n "$id" ] || continue
    dir="$SECTIONS/$id"
    [ -d "$dir" ] || { err "missing folder sections/$id"; continue; }
    [ -f "$dir/section.json" ] || err "missing $id/section.json"
    [ -f "$dir/Section.qml" ] || err "missing $id/Section.qml"
    [ -f "$dir/Model.qml" ] || err "missing $id/Model.qml"
    if [ -f "$dir/section.json" ]; then
        sid="$(jq -r '.id // empty' "$dir/section.json")"
        [ "$sid" = "$id" ] || err "section.json id '$sid' != $id"
    fi
    grep -qE "^[[:space:]]*${id}:[[:space:]]*\\{" "$CATALOG" || err "Catalog _byId missing $id"
    jq -e --arg k "$id" '.settings.sections[$k] | type == "string"' "$EN" >/dev/null \
        || err "en.json missing settings.sections.$id"
    jq -e --arg k "$id" '.settings.sections[$k] | type == "string"' "$DE" >/dev/null \
        || err "de.json missing settings.sections.$id"
done < <(printf '%s\n' "${IDS[@]}")

mapfile -t RESTORE_PATHS < <(python3 - "$CATALOG" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
# restore: ["a", "b.c"]
for m in re.finditer(r'restore:\s*\[(.*?)\]', text, re.S):
    for p in re.findall(r'"([^"]+)"', m.group(1)):
        print(p)
PY
)

for p in "${RESTORE_PATHS[@]}"; do
    has_path "$p" || err "restore path missing in config.default.json: $p"
done
ok "restore paths exist in config.default.json"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-catalog-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
mkdir -p "$TMP/modern"
cp "$DEFAULT" "$TMP/modern/config.default.json"
cp "$DEFAULT" "$TMP/modern/config.json"

declare -A SEEN=()
for p in "${RESTORE_PATHS[@]}"; do
    skip=0
    for s in $SKIP_MUTATE; do
        if [ "$p" = "$s" ] || [[ "$p" == "$s."* ]]; then
            skip=1
        fi
    done
    [ "$skip" -eq 1 ] && continue
    [ -z "${SEEN[$p]:-}" ] || continue
    SEEN["$p"]=1
    kind="$(jq -r --arg p "$p" 'getpath($p | split(".")) | type' "$DEFAULT")"
    case "$kind" in
        boolean) val="true" ;;
        number) val="0" ;;
        string) val='"catalog-test"' ;;
        object|array) continue ;;
        *) continue ;;
    esac
    XDG_CONFIG_HOME="$TMP" "$SET" "$p" "$val" >/dev/null
    XDG_CONFIG_HOME="$TMP" "$RESTORE" "$p" >/dev/null
    orig="$(jq -c --arg p "$p" 'getpath($p | split("."))' "$DEFAULT")"
    now="$(jq -c --arg p "$p" 'getpath($p | split("."))' "$TMP/modern/config.json")"
    [ "$orig" = "$now" ] || err "restore did not reset $p ($now != $orig)"
done
ok "config-set / restore round-trip (non D-Bus paths)"

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-settings-catalog: all passed\n'
