#!/usr/bin/env bash
# Unprivileged UFW status for Settings. Enable/disable go through
# pkexec `ufw-apply.sh`; add/delete still pkexec /usr/bin/ufw.
set -euo pipefail

python3 - <<'PY'
import os
import pathlib
import re

BIN = pathlib.Path("/usr/bin/ufw")
CONF = pathlib.Path("/etc/ufw/ufw.conf")
FILES = (
    (pathlib.Path("/etc/ufw/user.rules"), False),
    (pathlib.Path("/etc/ufw/user6.rules"), True),
)


def enabled() -> bool:
    try:
        text = CONF.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    for line in text.splitlines():
        if line.startswith("ENABLED="):
            return line.split("=", 1)[1].strip().lower() == "yes"
    return False


def decode_comment(hex_s: str) -> str:
    try:
        return bytes.fromhex(hex_s.strip()).decode("utf-8", errors="replace")
    except ValueError:
        return ""


def anywhere(addr: str) -> bool:
    return addr in ("0.0.0.0/0", "::/0", "any")


def format_row(n: int, action: str, proto: str, dport: str, src: str, direction: str, comment: str, v6: bool) -> str:
    to = dport if dport and dport != "any" else "Anywhere"
    if proto and proto != "any":
        to = f"{to}/{proto}" if to != "Anywhere" else f"Anywhere/{proto}"
    if v6 and "(v6)" not in to:
        to += " (v6)"
    frm = src if src and not anywhere(src) else "Anywhere"
    if v6 and frm == "Anywhere":
        frm += " (v6)"
    if comment:
        frm += f" # {comment}"
    act = action.upper()
    if act not in ("ALLOW", "DENY", "REJECT"):
        act = "ALLOW"
    direc = "OUT" if direction.startswith("out") else "IN"
    return f"[{n:2d}] {to:<26} {act} {direc}    {frm}"


def parse_file(path: pathlib.Path, v6: bool, start: int) -> tuple[list[str], int]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return [], start
    rows = []
    n = start
    for raw in text.splitlines():
        line = raw.strip()
        comment = ""
        if " comment=" in line:
            line, hex_s = line.split(" comment=", 1)
            comment = decode_comment(hex_s)
        m = re.match(r"^### tuple ###\s+(.*)$", line)
        if not m:
            continue
        parts = m.group(1).split()
        if len(parts) < 6:
            continue
        action, proto, dport, _dst, _sport, src = parts[:6]
        direction = parts[-1] if len(parts) >= 7 else "in"
        if "_" in direction:
            direction = direction.split("_", 1)[0]
        rows.append(format_row(n, action, proto, dport, src, direction, comment, v6))
        n += 1
    return rows, n


def main() -> None:
    if not os.access(BIN, os.X_OK):
        print("Status: missing")
        return
    if not enabled():
        print("Status: inactive")
        return
    print("Status: active")
    print()
    n = 1
    for path, v6 in FILES:
        rows, n = parse_file(path, v6, n)
        for row in rows:
            print(row)


main()
PY
