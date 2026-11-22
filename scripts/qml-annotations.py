#!/usr/bin/env python3
"""Find QML functions that type some parameters or the return value but
leave other parameters untyped.

Qt treats such a function as annotated and an untyped parameter as void,
so every call logs "<value> should be coerced to void because the
function called is insufficiently annotated". Fully untyped functions are
fine; mixed ones are not.

Usage: qml-annotations.py <dir>... [--fix]
--fix types every untyped parameter as `var`, which keeps the behaviour.
"""
import re
import sys
from pathlib import Path

SIG = re.compile(r'(function\s+\w+\s*\()([^)]*)(\)\s*(?::\s*[\w.]+)?\s*\{)')


def mixed(params, tail):
    parts = [p.strip() for p in params.split(",") if p.strip()]
    if not parts:
        return False
    typed = [":" in p for p in parts]
    return not all(typed) and (any(typed) or ":" in tail.split(")", 1)[1])


def typed(params):
    return ", ".join(p if ":" in p else f"{p}: var"
                     for p in (q.strip() for q in params.split(",")) if p)


def main():
    fix = "--fix" in sys.argv[1:]
    roots = [Path(a) for a in sys.argv[1:] if a != "--fix"]
    found = []
    for root, qml in sorted((r, q) for r in roots for q in r.rglob("*.qml")):
        text = qml.read_text()
        out = []
        for n, line in enumerate(text.split("\n"), 1):
            m = SIG.search(line)
            if m and mixed(m.group(2), m.group(3)):
                found.append(f"{qml.relative_to(root)}:{n}")
                if fix:
                    line = line[:m.start(2)] + typed(m.group(2)) + line[m.end(2):]
            out.append(line)
        if fix:
            qml.write_text("\n".join(out))
    if found and not fix:
        print("qml-annotations: type every parameter (`: var`) or none:", file=sys.stderr)
        for f in found:
            print("  ", f, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
