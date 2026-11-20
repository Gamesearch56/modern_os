#!/usr/bin/env bash
# Portrait install for the signed-in account. Never touches the real home
# or the login snapshot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-face-set: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-face-set: ok %s\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
export MODERN_SESSION_DIR="$TMP/missing-session"
unset XDG_CONFIG_HOME || true

python3 - "$TMP/pic.png" "$TMP/note.txt" <<'PY'
import pathlib, struct, sys, zlib
def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
row = b"\x00" + b"\xff\x00\x00" * 4
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * 4)) + chunk(b"IEND", b"")
pathlib.Path(sys.argv[1]).write_bytes(png)
pathlib.Path(sys.argv[2]).write_text("nope\n")
PY

FACE="$ROOT/scripts/face-set.sh"
if "$FACE" "$TMP/note.txt" >/dev/null 2>"$TMP/bad.err"; then
    err "a text file was accepted as a picture"
elif [ -e "$HOME/.face" ]; then
    err "a rejected picture was still installed"
else
    ok "a text file is not installed as the picture"
fi

if "$FACE" "$TMP/pic.png" >"$TMP/out" && cmp -s "$TMP/pic.png" "$HOME/.face"; then
    ok "a picture is installed as the account face"
else
    err "the picture was not installed"
fi

printf 'old\n' >"$HOME/.face.icon"
if "$FACE" clear && [ ! -e "$HOME/.face" ] && [ ! -e "$HOME/.face.icon" ]; then
    ok "clearing removes the picture"
else
    err "clearing left a picture behind"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
ok "done"
