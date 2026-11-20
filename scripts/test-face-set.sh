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

if "$FACE" "$TMP/pic.png" >"$TMP/out" && cmp -s "$TMP/pic.png" "$HOME/.face" \
    && [ "$("$FACE" --which)" = "have $HOME/.face" ]; then
    ok "a picture is installed as the account face"
else
    err "the picture was not installed"
fi

printf 'old\n' >"$HOME/.face.icon"
if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    if "$FACE" --edit "$TMP/pic.png" 90 '4x4+0+0' >"$TMP/edit.out" \
        && python3 -c 'import pathlib,sys; b=pathlib.Path(sys.argv[1]).read_bytes(); assert b[:2]==b"\xff\xd8"' "$HOME/.face"; then
        ok "an edited picture is installed"
    else
        err "the edited picture was not installed"
    fi
    if "$FACE" --edit "$TMP/pic.png" 0 'nope' >/dev/null 2>"$TMP/crop.err"; then
        err "a bad crop was accepted"
    else
        ok "a bad crop is refused"
    fi
else
    ok "edit skipped without ImageMagick"
fi

if "$FACE" clear && [ ! -e "$HOME/.face" ] && [ ! -e "$HOME/.face.icon" ] \
    && [ "$("$FACE" --which)" = "none" ]; then
    ok "clearing removes the picture"
else
    err "clearing left a picture behind"
fi

if command -v magick >/dev/null 2>&1 || command -v identify >/dev/null 2>&1; then
    size="$("$FACE" --size "$TMP/pic.png" 2>"$TMP/size.err" || true)"
    if [ "$size" = "4 4 " ] || [ "$size" = "4 4" ]; then
        ok "a picture reports its pixel size"
    else
        err "pixel size was '$size'"
    fi
else
    ok "size skipped without ImageMagick"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
ok "done"
