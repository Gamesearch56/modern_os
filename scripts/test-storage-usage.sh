#!/usr/bin/env bash
# Unprivileged coverage for storage-usage.sh. Never walks the live disk.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-storage-usage: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-storage-usage: ok %s\n' "$*"; }

SCRIPT="$ROOT/scripts/storage-usage.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-storage-usage-XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

protect="${MODERN_PROTECT_HOME:-}"
protect="${protect%/}"
if [ -n "$protect" ]; then
    case "$TMP" in
        "$protect"|"$protect"/*) echo "test-storage-usage: refusing protected home" >&2; exit 1 ;;
    esac
fi

HOME_FAKE="$TMP/home"
ROOT_FAKE="$TMP/root"
mkdir -p \
    "$HOME_FAKE/.local/share/Steam/steamapps" \
    "$HOME_FAKE/Downloads" \
    "$HOME_FAKE/.cache/thumb" \
    "$ROOT_FAKE/usr/bin" \
    "$ROOT_FAKE/var/cache/pacman" \
    "$ROOT_FAKE/snapshots/1"
printf 'game' >"$HOME_FAKE/.local/share/Steam/steamapps/app"
printf 'filefile' >"$HOME_FAKE/Downloads/a.bin"
printf 'cc' >"$HOME_FAKE/.cache/thumb/x"
printf 'appappapp' >"$ROOT_FAKE/usr/bin/x"
printf 'snap' >"$ROOT_FAKE/snapshots/1/info"

export MODERN_TEST_FIXTURE=1
export MODERN_USAGE_HOME="$HOME_FAKE"
export MODERN_USAGE_ROOT="$ROOT_FAKE"
# xdg-user-dir would point at the real home; the script skips it in fixture.
PATH="/usr/bin:/bin"

out="$("$SCRIPT")"
if python3 - "$out" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
need = ("games", "files", "apps", "cache", "backups")
missing = [k for k in need if k not in d]
if missing:
    raise SystemExit("missing " + ",".join(missing))
if d["games"] < 4:
    raise SystemExit(f"games {d['games']}")
if d["files"] < 8:
    raise SystemExit(f"files {d['files']}")
if d["apps"] < 9:
    raise SystemExit(f"apps {d['apps']}")
if d["cache"] < 2:
    raise SystemExit(f"cache {d['cache']}")
if d["backups"] < 4:
    raise SystemExit(f"backups {d['backups']}")
PY
then
    ok "reports category sizes from the fixture tree"
else
    err "fixture: $out"
fi

if grep -F 'Paths.script("storage-usage.sh")' \
    "$ROOT/stow/shell/.config/quickshell/modern/Services/StorageUsage.qml" >/dev/null; then
    ok "Settings usage is this script"
else
    err "StorageUsage.qml must call storage-usage.sh"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-storage-usage: ok\n'
