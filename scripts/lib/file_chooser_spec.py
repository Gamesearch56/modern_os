"""Portal FileChooser options to a Files chooser request, and its answer back.

Pure translation, no D-Bus: file-chooser-portal.py does the bus, this does
the meaning. Paths arrive as NUL-terminated byte arrays, filters as
(name, [(0 glob | 1 MIME type, pattern)]), answers leave as file URIs.
"""

import mimetypes
import os
import urllib.parse

MIME_GLOBS = "/usr/share/mime/globs2"
OK, CANCELLED, ENDED = 0, 1, 2


def _text(value):
    return str(value) if value is not None else ""


def _decode(value):
    """Portal paths and names arrive as NUL-terminated byte arrays."""
    if value is None:
        return ""
    return os.fsdecode(bytes(bytearray(int(b) for b in value)).split(b"\0", 1)[0])


def _bytes_path(value):
    path = _decode(value)
    return path if path.startswith("/") else ""


def _bytes_name(value):
    name = _decode(value)
    return name if name not in ("", ".", "..") and "/" not in name else ""


def mime_globs(mime, table=MIME_GLOBS):
    """Glob patterns for a MIME type; "image/*" matches the whole family."""
    want = _text(mime).strip().lower()
    if not want:
        return []
    family = want[:-1] if want.endswith("/*") else ""
    found = []
    try:
        with open(table, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("#"):
                    continue
                parts = line.rstrip("\n").split(":")
                if len(parts) < 3:
                    continue
                kind, pattern = parts[1].lower(), parts[2]
                if (kind.startswith(family) if family else kind == want) and pattern not in found:
                    found.append(pattern)
    except OSError:
        pass
    if not found:
        types = mimetypes.types_map.items()
        found = sorted({"*" + ext for ext, kind in types if (kind.startswith(family) if family else kind == want)})
    return found


def filter_globs(rules, table=MIME_GLOBS):
    """One portal filter's (type, pattern) rules as globs; 0 is a glob, 1 a MIME type."""
    out = []
    for kind, pattern in rules or []:
        for item in ([_text(pattern)] if int(kind) == 0 else mime_globs(pattern, table)):
            if item and item not in out:
                out.append(item)
    return out or ["*"]


def _filters(options, table):
    raw = list(options.get("filters") or [])
    current = options.get("current_filter")
    index = 0
    if current is not None:
        key = (_text(current[0]), [(int(k), _text(p)) for k, p in current[1]])
        match = [i for i, f in enumerate(raw) if (_text(f[0]), [(int(k), _text(p)) for k, p in f[1]]) == key]
        if match:
            index = match[0]
        elif not raw:
            raw = [current]
    shown = [{"name": _text(f[0]), "patterns": filter_globs(f[1], table)} for f in raw]
    return raw, shown, index


def request_spec(method, options, table=MIME_GLOBS):
    """What the Files window needs for one portal call, plus the raw filters for the answer."""
    options = dict(options or {})
    raw, shown, index = _filters(options, table)
    folder = _bytes_path(options.get("current_folder"))
    name = _text(options.get("current_name"))
    if method == "OpenFile":
        mode = "folder" if options.get("directory") else "open"
    elif method == "SaveFile":
        mode = "save"
        current = _bytes_path(options.get("current_file"))
        if current:
            folder, name = os.path.dirname(current) or "/", os.path.basename(current)
    else:
        mode = "folder"
        raw, shown, index = [], [], 0
    spec = {
        "mode": mode,
        "multiple": bool(options.get("multiple")) and mode == "open",
        "folder": folder,
        "name": name if "/" not in name else "",
        "filters": shown,
        "filter": index,
    }
    return spec, raw


def file_uri(path):
    return "file://" + urllib.parse.quote(path, safe="/")


def answer_results(method, answer, options, raw_filters):
    """Portal (response, results) from the window's answer; None means cancelled."""
    if not isinstance(answer, dict):
        return CANCELLED, {}
    paths = [p for p in answer.get("paths") or [] if isinstance(p, str) and p.startswith("/") and "\0" not in p]
    if not paths:
        return CANCELLED, {}
    if method == "SaveFiles":
        folder = paths[0]
        names = [_bytes_name(f) for f in options.get("files") or []]
        paths = [os.path.join(folder, n) for n in names if n]
        if not paths:
            return CANCELLED, {}
    results = {"uris": [file_uri(p) for p in paths]}
    choices = []
    for choice in options.get("choices") or []:
        default = _text(choice[3]) if len(choice) > 3 else ""
        choices.append((_text(choice[0]), default))
    if choices:
        results["choices"] = choices
    if raw_filters:
        at = answer.get("filter", 0)
        at = at if isinstance(at, int) and 0 <= at < len(raw_filters) else 0
        results["current_filter"] = raw_filters[at]
    return OK, results
