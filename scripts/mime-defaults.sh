#!/usr/bin/env bash
# Write XDG default apps for video/image/text/folders/mailto into mimeapps.list so
# Nautilus/Dolphin and xdg-open follow Settings → Applications. Settings
# itself never touches this file; ConfigWrite runs this after
# apps.defaults changes. Folders are set explicitly: kitty-open.desktop
# also claims inode/directory, which is why Steam "Browse files" opened
# a terminal. Mail pins x-scheme-handler/mailto to apps.defaults.mail.
#
# Usage:
#   mime-defaults.sh
#   mime-defaults.sh --video mpv.desktop --image imv.desktop --text org.gnome.gedit.desktop --files org.gnome.Nautilus.desktop --mail proton-mail.desktop
#
# Desktop ids default to config.json apps.defaults.videoPlayer /
# imageViewer / textEditor / fileManager / mail. Video/image MIME types come
# from each app's .desktop MimeType= line; text also pins TEXT_TYPES.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/modern/config.json"
MIMEAPPS="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
VIDEO_ID=""
IMAGE_ID=""
TEXT_ID=""
FILES_ID=""
MAIL_ID=""

usage() {
    cat <<'EOF'
Usage: mime-defaults.sh [--video DESKTOP] [--image DESKTOP] [--text DESKTOP] [--files DESKTOP] [--mail DESKTOP] [--config PATH] [--mimeapps PATH]
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --video) VIDEO_ID="${2:-}"; shift 2 ;;
        --image) IMAGE_ID="${2:-}"; shift 2 ;;
        --text) TEXT_ID="${2:-}"; shift 2 ;;
        --files) FILES_ID="${2:-}"; shift 2 ;;
        --mail) MAIL_ID="${2:-}"; shift 2 ;;
        --config) CONFIG="${2:-}"; shift 2 ;;
        --mimeapps) MIMEAPPS="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

desktop_id() {
    local id="$1"
    [ -n "$id" ] || return 0
    case "$id" in
        *.desktop) printf '%s\n' "$id" ;;
        *) printf '%s.desktop\n' "$id" ;;
    esac
}

from_config() {
    local key="$1"
    [ -f "$CONFIG" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    jq -r --arg k "$key" '.apps.defaults[$k] // empty' "$CONFIG" 2>/dev/null || true
}

desktop_file() {
    local id="$1"
    local d
    for d in \
        "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$id" \
        /usr/local/share/applications/"$id" \
        /usr/share/applications/"$id"; do
        if [ -f "$d" ]; then
            printf '%s\n' "$d"
            return 0
        fi
    done
    return 1
}

mime_types() {
    local file="$1"
    grep -E '^MimeType=' "$file" | head -n1 | cut -d= -f2- | tr ';' '\n' | sed '/^$/d'
}

[ -n "$VIDEO_ID" ] || VIDEO_ID="$(from_config videoPlayer)"
[ -n "$IMAGE_ID" ] || IMAGE_ID="$(from_config imageViewer)"
[ -n "$TEXT_ID" ] || TEXT_ID="$(from_config textEditor)"
[ -n "$FILES_ID" ] || FILES_ID="$(from_config fileManager)"
[ -n "$MAIL_ID" ] || MAIL_ID="$(from_config mail)"
[ -n "$VIDEO_ID" ] || VIDEO_ID="mpv.desktop"
[ -n "$IMAGE_ID" ] || IMAGE_ID="imv.desktop"
[ -n "$TEXT_ID" ] || TEXT_ID="org.gnome.gedit.desktop"
[ -n "$FILES_ID" ] || FILES_ID="org.gnome.Nautilus.desktop"
VIDEO_ID="$(desktop_id "$VIDEO_ID")"
IMAGE_ID="$(desktop_id "$IMAGE_ID")"
TEXT_ID="$(desktop_id "$TEXT_ID")"
FILES_ID="$(desktop_id "$FILES_ID")"
MAIL_ID="$(desktop_id "$MAIL_ID")"

pairs=""
add_role() {
    local id="$1"
    local file types t
    [ -n "$id" ] || return 0
    if ! file="$(desktop_file "$id")"; then
        echo "mime-defaults: no desktop file for $id" >&2
        return 0
    fi
    types="$(mime_types "$file")"
    if [ -z "$types" ]; then
        echo "mime-defaults: $id has no MimeType=" >&2
        return 0
    fi
    while IFS= read -r t; do
        pairs="${pairs}${t}=${id}"$'\n'
    done <<< "$types"
}

# Editors list text/plain only, so Nautilus would hand scripts, configs
# and source files to whatever claims them first (often a browser).
TEXT_TYPES="text/plain text/markdown text/x-log text/csv text/css text/x-readme
text/x-python text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr text/x-lua
text/x-java text/x-rust text/x-go text/x-makefile text/x-cmake text/x-patch
text/x-diff text/x-sql application/x-shellscript application/json
application/xml application/x-yaml application/toml application/x-desktop
application/x-zerosize"

add_text_role() {
    local id="$1" t
    [ -n "$id" ] || return 0
    if ! desktop_file "$id" >/dev/null; then
        echo "mime-defaults: no desktop file for $id" >&2
        return 0
    fi
    for t in $TEXT_TYPES; do
        pairs="${pairs}${t}=${id}"$'\n'
    done
}

# Do not take MimeType= from the file manager: kitty-open.desktop also
# lists inode/directory, and a FM .desktop can omit it. Always pin
# folders to Settings → Applications → File manager.
add_folder_role() {
    local id="$1"
    [ -n "$id" ] || return 0
    if ! desktop_file "$id" >/dev/null; then
        echo "mime-defaults: no desktop file for $id" >&2
        return 0
    fi
    pairs="${pairs}inode/directory=${id}"$'\n'
    pairs="${pairs}inode/mount-point=${id}"$'\n'
}

# mailto: is pinned even if the mail .desktop omits MimeType=.
add_mail_role() {
    local id="$1"
    [ -n "$id" ] || return 0
    if ! desktop_file "$id" >/dev/null; then
        echo "mime-defaults: no desktop file for $id" >&2
        return 0
    fi
    pairs="${pairs}x-scheme-handler/mailto=${id}"$'\n'
}

add_role "$VIDEO_ID"
add_role "$IMAGE_ID"
add_text_role "$TEXT_ID"
add_folder_role "$FILES_ID"
add_mail_role "$MAIL_ID"

if [ -z "$pairs" ]; then
    echo "mime-defaults: nothing to apply" >&2
    exit 0
fi

mkdir -p "$(dirname "$MIMEAPPS")"
export MIMEAPPS
export MIME_PAIRS="$pairs"
python3 - <<'PY'
import os, tempfile

pairs = {}
for line in os.environ.get("MIME_PAIRS", "").splitlines():
    if "=" not in line:
        continue
    mime, desktop = line.split("=", 1)
    mime, desktop = mime.strip(), desktop.strip()
    if mime and desktop:
        pairs[mime] = desktop

path = os.environ["MIMEAPPS"]
text = ""
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()

sections = []
current = None
body = {None: []}
for raw in text.splitlines():
    line = raw.rstrip("\n")
    if line.startswith("[") and line.endswith("]") and len(line) > 2:
        current = line[1:-1]
        if current not in body:
            sections.append(current)
            body[current] = []
        continue
    body.setdefault(current, []).append(line)

if "Default Applications" not in body:
    sections.append("Default Applications")
    body["Default Applications"] = []
if "Added Associations" not in body:
    sections.append("Added Associations")
    body["Added Associations"] = []

def upsert_default(lines, mime, desktop):
    key = mime + "="
    out, found = [], False
    for line in lines:
        if line.startswith(key):
            out.append(f"{mime}={desktop}")
            found = True
        else:
            out.append(line)
    if not found:
        if out and out[-1] != "":
            pass
        out.append(f"{mime}={desktop}")
    return out

def upsert_added(lines, mime, desktop):
    key = mime + "="
    out, found = [], False
    for line in lines:
        if not line.startswith(key):
            out.append(line)
            continue
        rest = line[len(key):]
        ids = [x for x in rest.split(";") if x]
        ids = [desktop] + [x for x in ids if x != desktop]
        out.append(mime + "=" + ";".join(ids) + (";" if ids else ""))
        found = True
    if not found:
        out.append(f"{mime}={desktop};")
    return out

def drop_removed(lines, mime, desktop):
    key = mime + "="
    out = []
    for line in lines:
        if not line.startswith(key):
            out.append(line)
            continue
        rest = line[len(key):]
        ids = [x for x in rest.split(";") if x and x != desktop]
        if ids:
            out.append(mime + "=" + ";".join(ids) + ";")
    return out

defaults = body["Default Applications"]
added = body["Added Associations"]
removed = body.get("Removed Associations", [])
for mime, desktop in sorted(pairs.items()):
    defaults = upsert_default(defaults, mime, desktop)
    added = upsert_added(added, mime, desktop)
    removed = drop_removed(removed, mime, desktop)
body["Default Applications"] = defaults
body["Added Associations"] = added
if "Removed Associations" in body:
    body["Removed Associations"] = removed

lines = []
if body.get(None):
    lines.extend(body[None])
    if lines and lines[-1] != "":
        lines.append("")
for name in sections:
    if name is None:
        continue
    lines.append(f"[{name}]")
    chunk = body.get(name, [])
    while chunk and chunk[-1] == "":
        chunk = chunk[:-1]
    lines.extend(chunk)
    lines.append("")
text = "\n".join(lines).rstrip() + "\n"

fd, tmp = tempfile.mkstemp(prefix="mimeapps.", dir=os.path.dirname(path) or ".")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)
except Exception:
    os.unlink(tmp)
    raise
PY

echo "mime-defaults: wrote $MIMEAPPS"
