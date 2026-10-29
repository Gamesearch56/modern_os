#!/usr/bin/env bash
# Privileged Snapper GC. Settings pkexecs one of: prune, clear, create.
# Snapshot 0 is the live system and is never deleted. Fixture env is
# ignored when running as root so a leaked pkexec environment cannot
# redirect deletes.
set -euo pipefail

die() { printf 'snapper-gc: ERROR: %s\n' "$*" >&2; exit 1; }

SNAPPER=/usr/bin/snapper
LIST="${MODERN_SNAPPER_LIST:-}"
DELETED="${MODERN_SNAPPER_DELETED:-}"

in_fixture() {
    [ "$(id -u)" -ne 0 ] && [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ -n "$LIST" ]
}

usage() {
    printf 'usage: snapper-gc.sh prune <3-20>|clear|create <description> [keep]|prune-from-config [config.json]\n' >&2
    exit 2
}

keep_ok() {
    [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 3 ] && [ "$1" -le 20 ]
}

list_user_nums() {
    if in_fixture; then
        [ -f "$LIST" ] || die "fixture list missing"
        awk '$1 ~ /^[1-9][0-9]*$/ { print $1 + 0 }' "$LIST"
    else
        python3 - <<'PY'
import json, subprocess, sys
try:
    raw = subprocess.check_output(
        ["/usr/bin/snapper", "-c", "root", "--jsonout", "list"],
        text=True,
    )
except (OSError, subprocess.CalledProcessError) as e:
    print(f"snapper-gc: ERROR: list failed: {e}", file=sys.stderr)
    sys.exit(1)
data = json.loads(raw)
rows = data.get("root") or []
for row in rows:
    try:
        n = int(row.get("number"))
    except (TypeError, ValueError):
        continue
    if n > 0:
        print(n)
PY
    fi | sort -n | uniq
}

delete_nums() {
    if [ "$#" -eq 0 ]; then
        return 0
    fi
    local n
    for n in "$@"; do
        [[ "$n" =~ ^[1-9][0-9]*$ ]] || die "invalid snapshot $n"
    done
    if in_fixture; then
        [ -n "$DELETED" ] || die "fixture deleted path missing"
        printf '%s\n' "$@" >>"$DELETED"
        return 0
    fi
    "$SNAPPER" -c root delete "$@"
}

cmd_prune() {
    local keep="${1:-}"
    keep_ok "$keep" || die "keep must be 3-20"
    local -a nums=()
    mapfile -t nums < <(list_user_nums)
    local extra=$((${#nums[@]} - keep))
    if [ "$extra" -le 0 ]; then
        return 0
    fi
    local -a doomed=("${nums[@]:0:extra}")
    delete_nums "${doomed[@]}"
}

cmd_clear() {
    local -a nums=()
    mapfile -t nums < <(list_user_nums)
    delete_nums "${nums[@]}"
}

desc_ok() {
    python3 -c 'import sys
s = sys.argv[1]
sys.exit(0 if s and 1 <= len(s) <= 64 and not s.startswith("-")
         and "\n" not in s and "\0" not in s else 1)' "$1"
}

cmd_create() {
    local desc="${1:-}"
    local keep="${2:-}"
    [ -n "$desc" ] || die "description required"
    desc_ok "$desc" || die "invalid description"
    if [ -n "$keep" ]; then
        keep_ok "$keep" || die "keep must be 3-20"
    fi
    if in_fixture; then
        [ -f "$LIST" ] || die "fixture list missing"
        local next
        next="$(awk 'BEGIN { m = 0 } $1 ~ /^[0-9]+$/ && ($1 + 0) > m { m = $1 + 0 }
            END { print m + 1 }' "$LIST")"
        printf '%s\n' "$next" >>"$LIST"
    else
        "$SNAPPER" -c root create --description "$desc"
    fi
    if [ -n "$keep" ]; then
        cmd_prune "$keep"
    fi
}

cmd_prune_from_config() {
    local cfg="${1:-}"
    local out
    out="$(python3 - "$cfg" <<'PY'
import json, os, sys
cfg = sys.argv[1] if len(sys.argv) > 1 else ""
backup = {}
if cfg and os.path.isfile(cfg):
    try:
        backup = (json.load(open(cfg)) or {}).get("backup") or {}
    except (OSError, json.JSONDecodeError):
        backup = {}
prune = backup.get("pruneEnabled", True)
if prune in (False, "false", "False", 0, "0"):
    print("skip")
    raise SystemExit(0)
keep = backup.get("keepCount", 8)
try:
    n = int(keep)
except (TypeError, ValueError):
    n = 8
if n < 3 or n > 20:
    n = 8
print(n)
PY
)"
    [ "$out" = skip ] && return 0
    cmd_prune "$out"
}

[ $# -ge 1 ] || usage
case "$1" in
    prune)
        [ $# -eq 2 ] || usage
        cmd_prune "$2"
        ;;
    clear)
        [ $# -eq 1 ] || usage
        cmd_clear
        ;;
    create)
        [ $# -eq 2 ] || [ $# -eq 3 ] || usage
        cmd_create "$2" "${3:-}"
        ;;
    prune-from-config)
        [ $# -le 2 ] || usage
        cmd_prune_from_config "${2:-}"
        ;;
    *)
        usage
        ;;
esac
