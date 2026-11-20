"""Reverse one recorded file change. The window keeps the stack."""

import grp

import files_places as places
import files_safe as safe


def _text(row, key):
    value = row.get(key)
    if not isinstance(value, str) or not value:
        raise safe.Refuse("refused")
    return value


def _optional(row, key):
    value = row.get(key) or ""
    if not isinstance(value, str):
        raise safe.Refuse("refused")
    return value


def _pairs(entry):
    rows = entry.get("pairs")
    if not isinstance(rows, list) or not rows:
        raise safe.Refuse("refused")
    found = []
    for row in rows:
        if not isinstance(row, dict):
            raise safe.Refuse("refused")
        found.append((_text(row, "from"), _text(row, "to")))
    return found


def _items(entry):
    rows = entry.get("items")
    if not isinstance(rows, list) or not rows:
        raise safe.Refuse("refused")
    found = []
    for row in rows:
        if not isinstance(row, dict):
            raise safe.Refuse("refused")
        found.append({"path": _text(row, "path"), "name": _optional(row, "name")})
    return found


def _mode(text):
    if len(text) != 9 or any(ch not in "01" for ch in text):
        raise safe.Refuse("bad-mode")
    mode = 0
    for i, ch in enumerate(text):
        if ch == "1":
            mode |= 1 << (8 - i)
    return mode


def _attrs(path, entry, restore):
    mode = _optional(entry, "modeFrom" if restore else "modeTo")
    other = _optional(entry, "modeTo" if restore else "modeFrom")
    if mode and mode != other:
        safe.chmod_nofollow(safe.clean(path), _mode(mode))
    owner = _optional(entry, "ownerFrom" if restore else "ownerTo")
    other_owner = _optional(entry, "ownerTo" if restore else "ownerFrom")
    if owner and owner != other_owner:
        import files_ops
        files_ops._chown(path, owner)
    group = _optional(entry, "groupFrom" if restore else "groupTo")
    other_group = _optional(entry, "groupTo" if restore else "groupFrom")
    if group and group != other_group:
        gid = grp.getgrnam(safe.account_name(group)).gr_gid
        safe.chgrp_nofollow(safe.clean(path), gid)


def _covered(entry, undo):
    import files_trash
    rows = entry.get("covered") or []
    if not isinstance(rows, list) or not rows:
        return
    updated = []
    for row in rows:
        if not isinstance(row, dict):
            raise safe.Refuse("refused")
        path = _text(row, "path")
        if undo:
            files_trash.restore_one(_text(row, "name"))
            updated.append({"path": path, "name": _text(row, "name")})
        else:
            stored = files_trash.trash_one(path)
            places.shift_drop([path])
            updated.append({"path": path, "name": stored})
    entry["covered"] = updated


def _move(entry, side):
    if side == "redo":
        _covered(entry, False)
    for src, dst in _pairs(entry):
        origin, target = (dst, src) if side == "undo" else (src, dst)
        landed = safe.move_exact(origin, target)
        places.shift_move([origin], [landed])
    if side == "undo":
        _covered(entry, True)
    return entry


def _presence(entry):
    # Imported here: trash imports the ops module that imports us.
    import files_trash
    where = entry.get("where")
    items = _items(entry)
    if where == "trash":
        _covered(entry, False)
        for item in items:
            if not item["name"]:
                raise safe.Refuse("refused")
            files_trash.restore_one(item["name"])
        entry["where"] = "paths"
        return entry
    if where != "paths":
        raise safe.Refuse("refused")
    updated = []
    for item in items:
        stored = files_trash.trash_one(item["path"])
        places.shift_drop([item["path"]])
        updated.append({"path": item["path"], "name": stored})
    entry["items"] = updated
    entry["where"] = "trash"
    _covered(entry, True)
    return entry


def _edit(entry, side):
    origin = _text(entry, "from")
    target = _text(entry, "to")
    if side == "undo":
        path = target
        if target != origin:
            path = safe.move_exact(target, origin)
            places.shift_move([target], [path])
        _attrs(path, entry, True)
        return entry
    _attrs(origin, entry, False)
    if target != origin:
        landed = safe.move_exact(origin, target)
        places.shift_move([origin], [landed])
    return entry


def apply(payload):
    side = payload.get("side")
    entry = payload.get("entry")
    if side not in ("undo", "redo") or not isinstance(entry, dict):
        raise safe.Refuse("refused")
    kind = entry.get("kind")
    if kind == "presence":
        return _presence(entry)
    if kind == "move":
        return _move(entry, side)
    if kind == "edit":
        return _edit(entry, side)
    raise safe.Refuse("refused")
