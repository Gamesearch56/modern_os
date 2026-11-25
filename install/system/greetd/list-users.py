#!/usr/bin/env python3
# Human login names for the greetd select. stdout is a JSON array.
# Skip nologin shells and the greeter system account — never a specific
# person's login. Admin is wheel/sudo, same rule as PasswdParse.isAdmin.
import grp
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
ADMIN_GROUPS = ("wheel", "sudo")


def admin_logins() -> set[str]:
    names: set[str] = set()
    for gname in ADMIN_GROUPS:
        try:
            g = grp.getgrnam(gname)
        except KeyError:
            continue
        names.update(g.gr_mem)
        for e in pwd.getpwall():
            if int(e.pw_gid) == int(g.gr_gid):
                names.add(e.pw_name)
    return names


def main() -> int:
    admins = admin_logins()
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
            "admin": login in admins,
        })
    json.dump(out, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
