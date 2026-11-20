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
if python3 -c 'import json,sys; rows=json.load(sys.stdin); assert rows and "created" in rows[0] and "mtime" in rows[0]' <<<"$created"; then
    ok "created and updated stamps are listed"
else
    err "listing omitted created or updated"
fi
mkdir -p "$TMP/box/c/sub"
printf 'abcd' >"$TMP/box/c/sub/nested"
if python3 -c 'import json,sys; rows=json.load(sys.stdin); row=next(r for r in rows if r["name"]=="c"); assert row["dir"] and row["size"]==-1' <<<"$listed"; then
    ok "a folder is listed before its contents are measured"
else
    err "folder size was measured during the listing"
fi
sizes="$("$OPS" sizes "$TMP/box" 0)"
if python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==4' "$TMP/box" <<<"$sizes"; then
    ok "folder totals are reported after the listing"
else
    err "folder total was wrong"
fi
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
if python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==1' "$TMP/box" <<<"$cached"; then
    ok "a saved folder size is reused"
else
    err "saved folder size was measured again"
fi
"$OPS" touch "$TMP/box/c" extra >/dev/null
changed="$("$OPS" sizes "$TMP/box" 0)"
if python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==4' "$TMP/box" <<<"$changed"; then
    ok "a changed folder is measured again"
else
    err "a changed folder kept its saved size"
fi
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
if python3 -c 'import json,os,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; m={r["path"]: r["size"] for r in rows}; assert m[os.path.join(sys.argv[1], "c")]==4' "$TMP/box" <<<"$fresh"; then
    ok "deleting the size cache measures the folder again"
else
    err "a deleted size cache was not measured again"
fi

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
mkdir -p "$TMP/one/folder" "$TMP/two/folder"
printf 'new\n' >"$TMP/one/clash"
printf 'old\n' >"$TMP/two/clash"
printf 'in\n' >"$TMP/two/folder/inside"
hits="$("$OPS" conflicts copy "$TMP/two" "$TMP/one/clash" "$TMP/one/folder")"
if python3 -c 'import json,sys; rows=json.loads(sys.argv[1]); names={r["name"]: r["dir"] for r in rows}; assert names["clash"] is False and names["folder"] is True and len(rows)==2' "$hits"; then
    ok "a taken name is reported before the copy"
else
    err "name clash was not reported: $hits"
fi
"$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"copy","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"keep"}]}))' "$TMP/two" "$TMP/one/clash")" >/dev/null
if [ "$(cat "$TMP/two/clash")" = "old" ] && [ "$(cat "$TMP/two/(2) clash")" = "new" ]; then
    ok "rename keeps the existing file and writes another name"
else
    err "rename did not keep both files"
fi
printf 'newer\n' >"$TMP/one/clash"
"$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"copy","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"replace"}]}))' "$TMP/two" "$TMP/one/clash")" >/dev/null
if [ "$(cat "$TMP/two/clash")" = "newer" ]; then
    ok "overwrite replaces the file"
else
    err "overwrite left the old file"
fi
before="$(find "$TMP/two" -maxdepth 1 -name '*clash' | wc -l)"
"$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"copy","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"replace"}]}))' "$TMP/two" "$TMP/two/clash")" >/dev/null
after="$(find "$TMP/two" -maxdepth 1 -name '*clash' | wc -l)"
if [ "$before" = "$after" ] && [ "$(cat "$TMP/two/clash")" = "newer" ]; then
    ok "overwrite of the same file does not add a numbered copy"
else
    err "overwrite of the same file created another copy"
fi
printf 'x\n' >"$TMP/two/(2) skip"
printf 'y\n' >"$TMP/two/skip"
printf 'z\n' >"$TMP/one/skip"
skip="$("$OPS" conflicts copy "$TMP/two" "$TMP/one/skip")"
if python3 -c 'import json,sys; row=json.loads(sys.argv[1])[0]; assert row["suggest"]=="(3) skip"' "$skip"; then
    ok "the suggested name skips numbers that already exist"
else
    err "suggested name was wrong: $skip"
fi
"$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"copy","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"name","name":"(3) skip"}]}))' "$TMP/two" "$TMP/one/skip")" >/dev/null
if [ "$(cat "$TMP/two/(3) skip")" = "z" ] && [ "$(cat "$TMP/two/skip")" = "y" ]; then
    ok "the chosen name is used for the new file"
else
    err "the chosen name was not written"
fi
trashed="$("$TRASH" list)"
if python3 -c 'import json,sys; rows=json.loads(sys.argv[1]); row=next(r for r in rows if str(r.get("original","")).endswith("/two/clash")); assert open(row["path"]).read()=="old\n"' "$trashed"; then
    ok "overwrite moves the existing file to the trash"
else
    err "overwrite did not keep the old file in the trash"
fi
printf 'safe\n' >"$TMP/link-target"
ln -s "$TMP/link-target" "$TMP/two/linkname"
printf 'fresh\n' >"$TMP/one/linkname"
"$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"move","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"replace"}]}))' "$TMP/two" "$TMP/one/linkname")" >/dev/null
if [ "$(cat "$TMP/two/linkname")" = "fresh" ] && [ "$(cat "$TMP/link-target")" = "safe" ] && [ ! -e "$TMP/one/linkname" ]; then
    ok "overwrite replaces a symlink and leaves its target"
else
    err "overwrite followed or kept the symlink"
fi
"$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"copy","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"replace"}]}))' "$TMP/two" "$TMP/one/folder")" >/dev/null
if [ -d "$TMP/two/folder" ] && [ ! -e "$TMP/two/folder/inside" ] && [ -f "$TMP/one/folder" ]; then
    err "overwrite left the folder contents or removed the source"
elif [ -d "$TMP/two/folder" ] && [ ! -e "$TMP/two/folder/inside" ]; then
    ok "overwrite moves an existing folder to the trash"
else
    err "overwrite did not replace the folder"
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
undo_note="$("$TRASH" move "$TMP/note")"
if [ -e "$TMP/note" ]; then
    err "undo fixture left the file in place"
fi
name="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["items"][0]["name"])' "$undo_note")"
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"undo","entry":{"kind":"presence","where":"trash","items":[{"path":sys.argv[1],"name":sys.argv[2]}]}}))' "$TMP/note" "$name")" >/dev/null
if [ "$(cat "$TMP/note")" = "hello" ]; then
    ok "undo puts a trashed file back"
else
    err "undo did not restore the trashed file"
fi
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"redo","entry":{"kind":"presence","where":"paths","items":[{"path":sys.argv[1],"name":sys.argv[2]}]}}))' "$TMP/note" "$name")" >/dev/null
if [ ! -e "$TMP/note" ]; then
    ok "redo moves the file to the trash again"
else
    err "redo left the restored file in place"
fi
"$TRASH" empty >/dev/null
mkdir -p "$TMP/box/away"
printf 'm\n' >"$TMP/box/moving"
"$OPS" move "$TMP/box/away" "$TMP/box/moving" >/dev/null
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"undo","entry":{"kind":"move","pairs":[{"from":sys.argv[1],"to":sys.argv[2]}]}}))' "$TMP/box/moving" "$TMP/box/away/moving")" >/dev/null
if [ "$(cat "$TMP/box/moving")" = "m" ] && [ ! -e "$TMP/box/away/moving" ]; then
    ok "undo puts a moved file back"
else
    err "undo did not return the moved file"
fi
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"redo","entry":{"kind":"move","pairs":[{"from":sys.argv[1],"to":sys.argv[2]}]}}))' "$TMP/box/moving" "$TMP/box/away/moving")" >/dev/null
if [ "$(cat "$TMP/box/away/moving")" = "m" ]; then
    ok "redo moves the file again"
else
    err "redo did not move the file"
fi
printf 'r\n' >"$TMP/box/old-name"
"$OPS" rename "$TMP/box/old-name" new-name >/dev/null
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"undo","entry":{"kind":"move","pairs":[{"from":sys.argv[1],"to":sys.argv[2]}]}}))' "$TMP/box/old-name" "$TMP/box/new-name")" >/dev/null
if [ "$(cat "$TMP/box/old-name")" = "r" ]; then
    ok "undo restores a renamed file"
else
    err "undo did not restore the old name"
fi
printf 'c\n' >"$TMP/box/source"
"$OPS" copy "$TMP/box" "$TMP/box/source" >/dev/null
copy="$TMP/box/(2) source"
if [ ! -f "$copy" ]; then
    err "copy did not land beside the original"
fi
copied="$("$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"undo","entry":{"kind":"presence","where":"paths","items":[{"path":sys.argv[1],"name":""}]}}))' "$copy")")"
if [ -f "$TMP/box/source" ] && [ ! -e "$copy" ]; then
    ok "undo removes a copy and keeps the original"
else
    err "undo did not remove the copy"
fi
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"redo","entry":json.loads(sys.argv[1])}))' "$copied")" >/dev/null
if [ "$(cat "$copy")" = "c" ]; then
    ok "redo puts the copy back"
else
    err "redo did not restore the copy"
fi
mkdir -p "$TMP/undo-src" "$TMP/undo-dest"
printf 'kept\n' >"$TMP/undo-dest/same"
printf 'incoming\n' >"$TMP/undo-src/same"
placed="$("$OPS" place "$(python3 -c 'import json,sys; print(json.dumps({"op":"copy","dest":sys.argv[1],"items":[{"src":sys.argv[2],"mode":"replace"}]}))' "$TMP/undo-dest" "$TMP/undo-src/same")")"
entry="$(python3 -c 'import json,sys; info=json.loads(sys.argv[1]); print(json.dumps({"side":"undo","entry":{"kind":"presence","where":"paths","items":[{"path":info["paths"][0],"name":""}],"covered":info["covered"]}}))' "$placed")"
back="$("$OPS" apply "$entry")"
if [ "$(cat "$TMP/undo-dest/same")" = "kept" ]; then
    ok "undo puts back a file that was overwritten"
else
    err "undo left the overwriting file"
fi
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"redo","entry":json.loads(sys.argv[1])}))' "$back")" >/dev/null
if [ "$(cat "$TMP/undo-dest/same")" = "incoming" ]; then
    ok "redo overwrites the file again"
else
    err "redo did not overwrite again"
fi
"$OPS" mkdir "$TMP/box" fresh-dir >/dev/null
made="$("$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"undo","entry":{"kind":"presence","where":"paths","items":[{"path":sys.argv[1],"name":""}]}}))' "$TMP/box/fresh-dir")")"
if [ ! -e "$TMP/box/fresh-dir" ]; then
    ok "undo removes a new folder"
else
    err "undo left the new folder"
fi
"$OPS" apply "$(python3 -c 'import json,sys; print(json.dumps({"side":"redo","entry":json.loads(sys.argv[1])}))' "$made")" >/dev/null
if [ -d "$TMP/box/fresh-dir" ]; then
    ok "redo creates the folder again"
else
    err "redo did not restore the folder"
fi
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
mkdir -p "$TMP/meta/detail-folder"
printf 'abcdef\n' >"$TMP/meta/detail-file.txt"
"$SEARCH" names --root "$TMP/meta" --scope folder --query detail >"$TMP/meta.json"
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
by = {r["name"]: r for r in rows}
folder = by["detail-folder"]
file = by["detail-file.txt"]
assert folder["dir"] is True and folder["mtime"] > 0 and folder["created"] > 0
assert folder["size"] == 0
assert file["dir"] is False and file["size"] == 7 and file["mtime"] > 0 and file["created"] > 0
assert file["kind"] == "txt"
' "$TMP/meta.json"; then
    ok "search hits include size and dates for the grid"
else
    err "search hits omitted size or dates"
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

mkdir -p "$TMP/bin" "$TMP/runtime/gvfs/smb-share:server=nas,share=media"
cat >"$TMP/bin/findmnt" <<'EOF'
#!/bin/sh
printf '%s\n' '{"filesystems":[{"fstype":"cifs","target":"/mnt/share","children":[{"fstype":"ext4","target":"/mnt/local"}]}]}'
EOF
cat >"$TMP/bin/gio" <<'EOF'
#!/bin/sh
if [ "$1" = list ]; then
    printf '%s\n' 'sftp://desk/'
    exit 0
fi
if [ "$1" = mount ]; then
    printf '%s' "$2" >"${MODERN_GIO_LOG:?}"
    exit 0
fi
exit 1
EOF
chmod +x "$TMP/bin/findmnt" "$TMP/bin/gio"
listed="$(PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/runtime" "$PLACES" mounts)"
if python3 -c 'import json,sys; rows=json.load(sys.stdin); paths={r["path"] for r in rows}; uris={r["uri"] for r in rows}; assert "/mnt/share" in paths and "/mnt/local" not in paths and any(r["path"].endswith("/gvfs/smb-share:server=nas,share=media") and r["uri"]=="smb://nas/media" for r in rows) and "sftp://desk" in uris' <<<"$listed"; then
    ok "network places list mounts, gvfs shares, and discovered servers"
else
    err "network places were incomplete"
    printf '%s\n' "$listed" >&2
fi
printf '' >"$TMP/gio.log"
if PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/runtime" MODERN_GIO_LOG="$TMP/gio.log" "$PLACES" connect 'nas/share' >/dev/null; then
    if [ "$(cat "$TMP/gio.log")" = "smb://nas/share" ]; then
        ok "a server name is mounted as smb"
    else
        err "connect did not ask gio to mount smb://nas/share"
    fi
else
    err "connecting to a server name failed"
fi
if PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/runtime" MODERN_GIO_LOG="$TMP/gio.log" "$PLACES" connect 'file:///etc/passwd' >/dev/null 2>&1; then
    err "a local file URI was accepted as a server"
else
    ok "a local file URI is not a server"
fi

ZIP="$ROOT/scripts/files-zip.sh"
mkdir -p "$TMP/pack/sub"
printf 'alpha\n' >"$TMP/pack/a.txt"
printf 'beta\n' >"$TMP/pack/sub/b.txt"
if "$ZIP" pack "$TMP/pack/bundle.zip" "$TMP/pack/a.txt" "$TMP/pack/sub" >/dev/null \
    && "$ZIP" unpack "$TMP/pack/bundle.zip" "$TMP/pack/out" >/dev/null \
    && [ "$(cat "$TMP/pack/out/a.txt")" = "alpha" ] && [ "$(cat "$TMP/pack/out/sub/b.txt")" = "beta" ]; then
    ok "a zip stores the selected files and extracts them into a folder"
else
    err "zip round-trip failed"
fi
if "$ZIP" pack "$TMP/pack/bundle.zip" "$TMP/pack/a.txt" >/dev/null 2>"$TMP/zip.err"; then
    err "a second zip was allowed to replace the first"
elif grep -q taken "$TMP/zip.err" && [ -f "$TMP/pack/bundle.zip" ]; then
    ok "a zip is not replaced when its name is taken"
else
    err "a taken zip name was not refused"
fi
python3 - "$TMP/pack/slip.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("../escape.txt", "pwned\n")
    archive.writestr("ok.txt", "safe\n")
PY
if "$ZIP" unpack "$TMP/pack/slip.zip" "$TMP/pack/slipped" >/dev/null 2>"$TMP/slip.err"; then
    err "a zip was allowed to write outside its folder"
elif [ ! -e "$TMP/escape.txt" ] && [ ! -e "$TMP/pack/escape.txt" ] && [ ! -e "$TMP/pack/slipped" ]; then
    ok "a zip cannot extract outside the new folder"
else
    err "a rejected zip left extracted files behind"
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

# Ctrl+C in the location field shell-escapes spaces. Pasting that
# string back has to stat the same file.
if python3 - "$ROOT" "$TMP" "$OPS" <<'PY'
import json, pathlib, subprocess, sys
root, tmp, ops = sys.argv[1:]
field = (pathlib.Path(root) / "stow/shell/.config/quickshell/modern/Widgets/MTextField.qml").read_text()
locate = (pathlib.Path(root) / "stow/shell/.config/quickshell/modern/Services/FilesLocate.qml").read_text()
def meta(src, name):
    needle = 'const meta = "'
    at = src.find(needle)
    if at < 0:
        raise SystemExit(f"missing shell meta in {name}")
    i = at + len(needle)
    raw = []
    while i < len(src):
        if src[i] == "\\" and i + 1 < len(src):
            raw.append(src[i:i + 2])
            i += 2
            continue
        if src[i] == '"':
            break
        raw.append(src[i])
        i += 1
    return "".join(raw).encode("utf-8").decode("unicode_escape")
copied = meta(field, "MTextField")
pasted = meta(locate, "FilesLocate")
if copied != pasted:
    raise SystemExit("location copy and paste do not escape the same characters")
def escape(path):
    return "".join(("\\" + ch) if ch in copied else ch for ch in path)
def unescape(text):
    out, i = [], 0
    while i < len(text):
        if text[i] == "\\" and i + 1 < len(text) and text[i + 1] in pasted:
            out.append(text[i + 1])
            i += 2
            continue
        out.append(text[i])
        i += 1
    return "".join(out)
folder = pathlib.Path(tmp) / "My Documents"
folder.mkdir()
target = folder / "note file.txt"
target.write_text("ok\n")
raw = str(target)
escaped = escape(raw)
if "\\ " not in escaped or unescape(escaped) != raw:
    raise SystemExit(f"space round-trip failed: {escaped!r}")
out = subprocess.check_output([ops, "stat", unescape(escaped)], text=True)
info = json.loads(out)
if info.get("path") != raw or info.get("name") != "note file.txt":
    raise SystemExit(f"stat missed the spaced path: {info}")
PY
then
    ok "a shell-copied path with spaces pastes back to the same file"
else
    err "a shell-copied path with spaces did not resolve"
fi

[ "$FAIL" -eq 0 ]
printf 'test-files: ok\n'
