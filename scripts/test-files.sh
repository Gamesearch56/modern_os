#!/usr/bin/env bash
# Trash round-trip, sort order, search argv, refused deletes, and chmod.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS="$ROOT/scripts/files-ops.sh"
TRASH="$ROOT/scripts/files-trash.sh"
SEARCH="$ROOT/scripts/files-search.sh"
FAIL=0
err() { printf 'test-files: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-files: ok %s\n' "$*"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/modern-files-XXXXXX")"
trap 'chmod -R u+w "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT
export XDG_DATA_HOME="$TMP/data"
export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/data"

mkdir -p "$TMP/box/c" "$TMP/box/d"
printf 'a\n' >"$TMP/box/a"
printf 'b\n' >"$TMP/box/b"
listed="$("$OPS" list "$TMP/box" 0 name 1 1)"
names="$(python3 -c 'import json,sys; print("\n".join(row["name"] for row in json.load(sys.stdin)))' <<<"$listed")"
if [ "$names" = $'d\nc\nb\na' ]; then
    ok "folders stay first and names sort descending"
else
    err "sort order was: $(printf '%s' "$names" | tr '\n' ' ')"
fi
created="$("$OPS" list "$TMP/box" 0 created 0 0)"
python3 -c 'import json,sys; rows=json.load(sys.stdin); assert rows and "created" in rows[0] and "mtime" in rows[0]' <<<"$created" \
    && ok "created and updated stamps are listed" \
    || err "listing omitted created or updated"
mkdir -p "$TMP/box/c/sub"
printf 'abcd' >"$TMP/box/c/sub/nested"
python3 -c 'import json,sys; rows=json.load(sys.stdin); row=next(r for r in rows if r["name"]=="c"); assert row["dir"] and row["size"]==-1' <<<"$listed" \
    && ok "a folder is listed before its contents are measured" \
    || err "folder size was measured during the listing"
sizes="$("$OPS" sizes "$TMP/box" 0)"
python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==4' "$TMP/box" <<<"$sizes" \
    && ok "folder totals are reported after the listing" \
    || err "folder total was wrong"
python3 - "$TMP/box" <<'PY' || err "folder size cache was not written"
import hashlib, json, os, pathlib, sys
folder = os.path.join(sys.argv[1], "c")
digest = hashlib.sha256(os.fsencode(folder)).hexdigest()
root = pathlib.Path(os.environ["HOME"]) / ".cache" / "modern" / "folder-sizes"
path = root / digest[:2] / (digest + ".json")
row = json.loads(path.read_text())
row["size"] = 1
path.write_text(json.dumps(row) + "\n")
PY
cached="$("$OPS" sizes "$TMP/box" 0)"
python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==1' "$TMP/box" <<<"$cached" \
    && ok "a saved folder size is reused" \
    || err "saved folder size was measured again"
"$OPS" touch "$TMP/box/c" extra >/dev/null
changed="$("$OPS" sizes "$TMP/box" 0)"
python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==4' "$TMP/box" <<<"$changed" \
    && ok "a changed folder is measured again" \
    || err "a changed folder kept its saved size"
python3 - "$TMP/box" <<'PY' || err "folder size cache was not written again"
import hashlib, json, os, pathlib, sys
folder = os.path.join(sys.argv[1], "c")
digest = hashlib.sha256(os.fsencode(folder)).hexdigest()
root = pathlib.Path(os.environ["HOME"]) / ".cache" / "modern" / "folder-sizes"
path = root / digest[:2] / (digest + ".json")
row = json.loads(path.read_text())
row["size"] = 1
path.write_text(json.dumps(row) + "\n")
PY
rm -rf "$HOME/.cache/modern/folder-sizes"
fresh="$("$OPS" sizes "$TMP/box" 0)"
python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==4' "$TMP/box" <<<"$fresh" \
    && ok "deleting the size cache measures the folder again" \
    || err "a deleted size cache was not measured again"

if "$OPS" delete /etc >/dev/null 2>"$TMP/etc.err"; then
    err "delete of /etc was allowed"
elif [ -d /etc ]; then
    ok "delete of /etc is refused"
else
    err "/etc is missing after a refused delete"
fi

mkdir -p "$TMP/locked"
printf 'keep\n' >"$TMP/locked/secret"
chmod 555 "$TMP/locked"
if "$OPS" delete "$TMP/locked/secret" >/dev/null 2>"$TMP/lock.err"; then
    err "delete was allowed inside a directory the user cannot write"
elif [ -f "$TMP/locked/secret" ]; then
    ok "a file the user cannot write is left in place"
else
    err "the unwritable file disappeared"
fi
chmod 755 "$TMP/locked"

before="$(stat -c %a /etc/passwd)"
if "$OPS" chmod /etc/passwd 111111111 >/dev/null 2>"$TMP/mode.err"; then
    err "chmod of a file the user does not own was allowed"
fi
after="$(stat -c %a /etc/passwd)"
if [ "$before" = "$after" ]; then
    ok "chmod is rejected when the user is not the owner"
else
    err "chmod changed /etc/passwd from $before to $after"
fi

printf 'secret\n' >"$TMP/box/a"
if "$OPS" touch "$TMP/box" a >/dev/null 2>"$TMP/touch.err"; then
    err "creating an existing file was allowed"
elif [ "$(cat "$TMP/box/a")" = "secret" ]; then
    ok "creating an existing file leaves its contents"
else
    err "creating an existing file changed its contents"
fi
printf 'keep\n' >"$TMP/box/b"
if "$OPS" rename "$TMP/box/a" b >/dev/null 2>"$TMP/rename.err"; then
    err "rename replaced an existing file"
elif [ "$(cat "$TMP/box/b")" = "keep" ] && [ "$(cat "$TMP/box/a")" = "secret" ]; then
    ok "rename leaves both files when the new name exists"
else
    err "rename clobber check failed"
fi
mkdir -p "$TMP/box/dest"
printf 'dst\n' >"$TMP/box/dest/a"
if ! "$OPS" copy "$TMP/box/dest" "$TMP/box/a" >/dev/null 2>"$TMP/copy.err"; then
    err "copy failed when the destination name already existed"
elif [ "$(cat "$TMP/box/dest/a")" = "dst" ] && [ "$(cat "$TMP/box/dest/(2) a")" = "secret" ]; then
    ok "copy keeps the existing file and writes a new name"
else
    err "copy replaced or dropped a file"
fi
printf 'same\n' >"$TMP/box/same.txt"
if ! "$OPS" copy "$TMP/box" "$TMP/box/same.txt" >/dev/null 2>"$TMP/same.err"; then
    err "copy into the same folder failed"
elif [ "$(cat "$TMP/box/same.txt")" = "same" ] && [ "$(cat "$TMP/box/(2) same.txt")" = "same" ]; then
    ok "a file pasted beside itself is renamed first"
else
    err "a file pasted beside itself was replaced or dropped"
fi
printf 'self\n' >"$TMP/box/self.txt"
if ! "$OPS" copy "$TMP/box/self.txt" "$TMP/box/self.txt" >/dev/null 2>"$TMP/self.err"; then
    err "copy aimed at the file itself failed"
elif [ "$(cat "$TMP/box/self.txt")" = "self" ] && [ "$(cat "$TMP/box/(2) self.txt")" = "self" ]; then
    ok "a paste aimed at the file lands beside it"
else
    err "a paste aimed at the file did not land beside it"
fi
printf 'safe\n' >"$TMP/keep-target"
ln -s "$TMP/keep-target" "$TMP/box/link"
"$OPS" delete "$TMP/box/link" >/dev/null
if [ -f "$TMP/keep-target" ] && [ ! -e "$TMP/box/link" ]; then
    ok "deleting a symlink leaves its target"
else
    err "deleting a symlink changed the target"
fi
mkdir -p "$TMP/keepdir"
printf 'safe\n' >"$TMP/keepdir/safe"
mkdir -p "$TMP/box/outer"
ln -s "$TMP/keepdir" "$TMP/box/outer/jump"
"$OPS" delete "$TMP/box/outer" >/dev/null
if [ -f "$TMP/keepdir/safe" ] && [ ! -e "$TMP/box/outer" ]; then
    ok "deleting a folder does not follow a symlink inside it"
else
    err "deleting a folder followed a symlink"
fi
ln -s /etc "$TMP/box/etc-link"
if "$OPS" touch "$TMP/box/etc-link" modern-files-should-not-exist >/dev/null 2>"$TMP/link.err"; then
    err "create through a symlink into /etc was allowed"
elif [ -e /etc/modern-files-should-not-exist ]; then
    err "create through a symlink wrote into /etc"
else
    ok "create through a symlink into /etc is refused"
fi
mkdir -p "$TMP/box/tree/nested"
if "$OPS" copy "$TMP/box/tree/nested" "$TMP/box/tree" >/dev/null 2>"$TMP/into.err"; then
    err "copying a folder into itself was allowed"
else
    ok "copying a folder into itself is refused"
fi
printf 'x\n' >"$TMP/box/mode-target"
chmod 600 "$TMP/box/mode-target"
ln -s mode-target "$TMP/box/mode-link"
if "$OPS" chmod "$TMP/box/mode-link" 111111111 >/dev/null 2>"$TMP/slink.err"; then
    err "chmod followed a symlink"
fi
if [ "$(stat -c %a "$TMP/box/mode-target")" = "600" ]; then
    ok "chmod does not change the target of a symlink"
else
    err "chmod changed the target of a symlink"
fi
printf 'z\n' >"$TMP/box/editme"
"$OPS" edit "$TMP/box/editme" --name edited --mode 110100000 >/dev/null
if [ -f "$TMP/box/edited" ] && [ ! -e "$TMP/box/editme" ] && [ "$(stat -c %a "$TMP/box/edited")" = "640" ]; then
    ok "rename and mode change happen on the same file"
else
    err "combined edit did not rename and set the mode"
fi
printf '1\n' >"$TMP/t1"
printf '2\n' >"$TMP/t2"
"$TRASH" move "$TMP/t1" "$TMP/t2" >/dev/null
if [ ! -e "$TMP/t1" ] && [ ! -e "$TMP/t2" ]; then
    ok "several files are trashed by one rename"
else
    err "trashing several files left one behind"
fi

printf 'hello\n' >"$TMP/note"
"$TRASH" move "$TMP/note" >/dev/null
if [ -e "$TMP/note" ]; then
    err "trash left the original file"
fi
"$TRASH" list >"$TMP/trash.json"
if python3 -c 'import json,sys; rows=json.load(open(sys.argv[1])); note=next(r for r in rows if r["name"]=="note"); assert note["size"]==6 and note["mtime"]>0 and note["created"]>0 and note["kind"]=="file"' "$TMP/trash.json"; then
    ok "trashed file is listed with size and dates"
else
    err "trashed file was not listed with its details"
fi
"$TRASH" restore note >/dev/null
if [ "$(cat "$TMP/note")" = "hello" ]; then
    ok "restore puts the file back"
else
    err "restore did not return the file"
fi
"$TRASH" move "$TMP/note" >/dev/null
"$TRASH" empty >/dev/null
left="$("$TRASH" list)"
if [ "$left" = "[]" ]; then
    ok "empty trash removes only that trash"
else
    err "trash was not emptied: $left"
fi

mkdir -p "$TMP/scan"
printf 'x\n' >"$TMP/scan/ok; echo PWNED"
marker="$TMP/PWNED"
"$SEARCH" names --root "$TMP/scan" --scope folder --query 'ok; echo PWNED' >"$TMP/found.json"
if [ ! -e "$marker" ] && python3 -c '
import json, sys
rows = []
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    obj = json.loads(line)
    if isinstance(obj.get("replace"), list):
        rows = obj["replace"]
    elif "name" in obj:
        rows.append(obj)
assert any("PWNED" in r.get("name", "") for r in rows)
' "$TMP/found.json"; then
    ok "a search query is not executed as a shell command"
else
    err "search argv was unsafe"
fi
mkdir -p "$TMP/rank/games/World of Warcraft Forever Game"
python3 -c '
import os, sys
root = sys.argv[1]
os.makedirs(os.path.join(root, "notes"), exist_ok=True)
for i in range(40):
    with open(os.path.join(root, "notes", "game-%d.txt" % i), "w", encoding="utf-8") as fh:
        fh.write("x\n")
    with open(os.path.join(root, "wow-forever-game-notes-%d.txt" % i), "w", encoding="utf-8") as fh:
        fh.write("x\n")
' "$TMP/rank"
"$SEARCH" names --root "$TMP/rank" --scope folder --query "wow forever game" >"$TMP/rank.json"
if python3 -c '
import json, sys
rows = []
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    obj = json.loads(line)
    if isinstance(obj.get("replace"), list):
        rows = obj["replace"]
names = [r.get("name", "") for r in rows]
assert "World of Warcraft Forever Game" in names, names
assert not any(name.startswith("game-") for name in names), names
ordered = sorted(rows, key=lambda r: (0 if r.get("dir") else 1, -r.get("score", 0), r.get("name", "").casefold()))
assert ordered[0]["name"] == "World of Warcraft Forever Game", ordered[0]
assert ordered[0]["dir"] is True
' "$TMP/rank.json"; then
    ok "an acronym query keeps the closest folder above weaker names"
else
    err "search ranking missed the closest folder"
fi
mkdir -p "$TMP/hide/.local/share/Steam/steamapps/compatdata/1/pfx/drive_c/World of Warcraft/_forever_/Interface/AddOns/Questie/Forever"
mkdir -p "$TMP/hide/notes"
printf 'x\n' >"$TMP/hide/notes/forever.txt"
"$SEARCH" names --root "$TMP/hide" --scope folder --query "Forever" --hidden 0 >"$TMP/hide.json"
if python3 -c '
import json, sys
rows = []
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    obj = json.loads(line)
    if isinstance(obj.get("replace"), list):
        rows = obj["replace"]
dirs = [r for r in rows if r.get("dir")]
assert dirs, rows
ordered = sorted(dirs, key=lambda r: (-r.get("score", 0), r.get("name", "").casefold()))
assert ordered[0]["name"] == "_forever_", ordered[0]
assert all("/AddOns/" not in ordered[0]["path"] for _ in [0])
addon = [r for r in dirs if r.get("name") == "Forever"]
assert addon and addon[0]["score"] < ordered[0]["score"]
' "$TMP/hide.json"; then
    ok "a hidden install folder outranks addon copies of the same name"
else
    err "search missed the install folder under a hidden parent"
fi
if ! grep -n 'shell=True' "$ROOT/scripts/lib/files_search.py" "$ROOT/scripts/lib/files_ops.py" "$ROOT/scripts/lib/files_trash.py" "$ROOT/scripts/lib/files_thumbs.py" >/dev/null; then
    ok "file scripts do not invoke a shell"
else
    err "a file script uses shell=True"
fi
if python3 -c 'import importlib.util,sys; p=sys.argv[1]; s=importlib.util.spec_from_file_location("bus", p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); assert m.local_path("file:///tmp/shot%20a.png")=="/tmp/shot a.png"; assert m.local_path("file:///tmp/../etc")==""; assert m.local_path("/home/downloads")=="/home/downloads"' "$ROOT/scripts/file-manager-bus.py"; then
    ok "folder requests decode a file uri and reject parent escapes"
else
    err "file-manager bus path check failed"
fi

mkdir -p "$TMP/vol"
printf 'x\n' >"$TMP/vol/portable.txt"
"$SEARCH" names --root "$TMP/vol" --scope folder --query portable >"$TMP/vol.json"
"$SEARCH" names --root "$HOME" --scope home --query portable >"$TMP/home-search.json"
if python3 -c '
import json, sys
def rows(path):
    found = []
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        if isinstance(obj.get("replace"), list):
            found = obj["replace"]
    return found
vol, home = rows(sys.argv[1]), rows(sys.argv[2])
assert any(r.get("name") == "portable.txt" for r in vol), vol
assert not any(r.get("name") == "portable.txt" for r in home), home
' "$TMP/vol.json" "$TMP/home-search.json"; then
    ok "a folder scope can search a storage outside home"
else
    err "search did not stay on the chosen storage"
fi

PLACES="$ROOT/scripts/files-places.sh"
printf 'z\n' >"$HOME/opened.txt"
"$PLACES" record "$HOME/opened.txt" >/dev/null
if "$PLACES" record "$TMP/missing-file" >/dev/null 2>"$TMP/rec.err"; then
    err "recording a missing file was allowed"
else
    ok "recording a missing file is refused"
fi
if python3 -c 'import json,os,sys; rows=json.load(sys.stdin); hit=next(r for r in rows if r["path"]==sys.argv[1]); assert hit["dir"] is False and hit["readable"] is True' "$HOME/opened.txt" <<<"$("$PLACES" recent)"; then
    ok "an opened file is listed in recent"
else
    err "recent did not list the opened file"
fi

THUMBS="$ROOT/scripts/files-thumbs.sh"
mkdir -p "$TMP/pics"
python3 - "$TMP/pics/dot.png" "$TMP/pics/note.txt" <<'PY'
import pathlib, struct, sys, zlib
def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
row = b"\x00" + b"\xff\x00\x00" * 8
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * 8)) + chunk(b"IEND", b"")
pathlib.Path(sys.argv[1]).write_bytes(png)
pathlib.Path(sys.argv[2]).write_text("hello\n")
PY
if command -v magick >/dev/null 2>&1 || command -v ffmpeg >/dev/null 2>&1; then
    thumb_out="$(XDG_CACHE_HOME="$TMP/cache" "$THUMBS" "$TMP/pics/dot.png" "$TMP/pics/note.txt")"
    thumb_dest="$(printf '%s\n' "$thumb_out" | awk -F '\t' 'NR==1 { print $2 }')"
    if [ "$(printf '%s\n' "$thumb_out" | grep -c .)" -eq 1 ] && [ -s "$thumb_dest" ] \
        && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import files_thumbs; assert files_thumbs.read_mtime(sys.argv[2])' "$ROOT/scripts/lib" "$thumb_dest"; then
        ok "an image gets a thumbnail and a text file does not"
    else
        err "image thumbnail missing"
    fi
    if [ -n "$thumb_dest" ]; then
        before="$(stat -c %Y "$thumb_dest")"
        sleep 1
        XDG_CACHE_HOME="$TMP/cache" "$THUMBS" "$TMP/pics/dot.png" >/dev/null
        after="$(stat -c %Y "$thumb_dest")"
        if [ "$before" = "$after" ]; then
            ok "a fresh thumbnail is reused"
        else
            err "thumbnail was rebuilt"
        fi
    fi
else
    ok "thumbnail tools are not installed"
fi
if command -v ffmpeg >/dev/null 2>&1; then
    if ffmpeg -y -loglevel error -f lavfi -i color=c=red:s=64x64:d=1 "$TMP/pics/clip.mp4" >/dev/null 2>&1; then
        video_out="$(XDG_CACHE_HOME="$TMP/cache" "$THUMBS" "$TMP/pics/clip.mp4")"
        video_dest="$(printf '%s\n' "$video_out" | awk -F '\t' 'NR==1 { print $2 }')"
        if [ -s "$video_dest" ]; then
            ok "a video gets a thumbnail"
        else
            err "video thumbnail missing"
        fi
    else
        ok "video sample could not be encoded"
    fi
fi

[ "$FAIL" -eq 0 ]
printf 'test-files: ok\n'
