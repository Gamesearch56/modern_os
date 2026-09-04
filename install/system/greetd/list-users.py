#!/usr/bin/env python3
# Human login names for the greetd select. stdout is a JSON array.
# Skip nologin shells and the greeter system account — never a specific
# person's login.
import json
import pwd
import sys

SKIP_USER = {"greeter", "nobody", "nfsnobody"}
SKIP_SHELL = {
    "/usr/bin/nologin",
    "/sbin/nologin",
    "/usr/sbin/nologin",
    "/bin/false",
    "/usr/bin/false",
    "/sbin/false",
}


def main() -> int:
    out = []
    for e in pwd.getpwall():
        login = e.pw_name or ""
        if not login or login in SKIP_USER:
            continue
        if not (1000 <= int(e.pw_uid) < 65534):
            continue
        shell = e.pw_shell or ""
        if shell in SKIP_SHELL or "nologin" in shell:
            continue
        gecos = (e.pw_gecos or "").split(",")[0].strip()
        out.append({
            "value": login,
            "titleValue": gecos if gecos else login,
            "home": e.pw_dir or "",
        })
    json.dump(out, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
