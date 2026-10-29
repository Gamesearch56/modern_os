#!/usr/bin/env bash
# Privileged UFW comment rewrite. Settings pkexecs this so a description
# change does not delete and re-add the rule (that would be two prompts
# and a brief hole). Numbering matches ufw-status.sh: user.rules, then
# user6.rules, ### tuple ### lines only. Comments are not in netfilter,
# so this does not reload UFW.
set -euo pipefail

die() { printf 'ufw-comment: ERROR: %s\n' "$*" >&2; exit 1; }

NUM="${1:-}"
COMMENT="${2:-}"
[[ "$NUM" =~ ^[1-9][0-9]{0,2}$ ]] || die "usage: ufw-comment.sh <number> [comment]"

ROOT=/etc/ufw
if [ "$(id -u)" -ne 0 ] && [ "${MODERN_TEST_FIXTURE:-}" = "1" ] && [ -n "${UFW_COMMENT_ROOT:-}" ]; then
    ROOT="$UFW_COMMENT_ROOT"
fi

export UFW_COMMENT_ROOT="$ROOT"
export UFW_COMMENT_NUM="$NUM"
export UFW_COMMENT_TEXT="$COMMENT"
python3 - <<'PY'
import os
import pathlib
import re
import stat
import sys
import tempfile

ROOT = pathlib.Path(os.environ["UFW_COMMENT_ROOT"])
NUM = int(os.environ["UFW_COMMENT_NUM"])
COMMENT = os.environ["UFW_COMMENT_TEXT"]
FILES = (ROOT / "user.rules", ROOT / "user6.rules")
OK = re.compile(r"^[A-Za-z0-9._: -]+$")


def comment_ok(s: str) -> bool:
    t = s.strip()
    if t == "":
        return True
    return len(t) <= 40 and t[0] != "-" and OK.fullmatch(t) is not None


def rewrite_tuple(stripped: str, comment: str) -> str:
    if " comment=" in stripped:
        stripped = stripped.split(" comment=", 1)[0].rstrip()
    if comment:
        stripped += " comment=" + comment.encode("utf-8").hex()
    return stripped


def apply() -> None:
    if not comment_ok(COMMENT):
        print("ufw-comment: ERROR: invalid comment", file=sys.stderr)
        sys.exit(1)
    comment = COMMENT.strip()
    seen = 0
    for path in FILES:
        if not path.is_file() or path.is_symlink():
            continue
        raw = path.read_bytes()
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            print("ufw-comment: ERROR: rules file is not utf-8", file=sys.stderr)
            sys.exit(1)
        nl = "\n" if text.endswith("\n") or text == "" else ""
        lines = text.splitlines()
        changed = False
        out = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("### tuple ###"):
                seen += 1
                if seen == NUM:
                    indent = line[: len(line) - len(line.lstrip())]
                    out.append(indent + rewrite_tuple(stripped, comment))
                    changed = True
                    continue
            out.append(line)
        if not changed:
            continue
        # mkstemp is 0600. Status is unprivileged and must keep reading
        # this file, so copy the original mode onto the replacement.
        mode = path.stat().st_mode
        uid = path.stat().st_uid
        gid = path.stat().st_gid
        body = "\n".join(out) + nl
        fd, tmp = tempfile.mkstemp(prefix=".ufw-comment.", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(body)
            os.chmod(tmp, stat.S_IMODE(mode))
            os.chown(tmp, uid, gid)
            os.replace(tmp, path)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
        return
    print("ufw-comment: ERROR: no such rule", file=sys.stderr)
    sys.exit(1)


apply()
PY
