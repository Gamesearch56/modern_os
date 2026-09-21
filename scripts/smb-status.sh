#!/usr/bin/env bash
# Unprivileged Samba status for Settings. Mutate goes through pkexec
# smb-setup.sh / smb-apply.sh.
set -euo pipefail

python3 - <<'PY'
import json
import os
import pathlib
import shutil
import subprocess

CONF = pathlib.Path(os.environ.get("MODERN_SMB_CONF", "/etc/samba/smb.conf"))
SMBD = pathlib.Path(os.environ.get("MODERN_SMB_BIN", "/usr/sbin/smbd"))
SYSTEMCTL = os.environ.get("MODERN_SMB_SYSTEMCTL", "/usr/bin/systemctl")


def missing() -> dict:
    return {
        "status": "missing",
        "name": "",
        "share": "",
        "path": "",
        "guest": False,
    }


def parse_conf(text: str) -> dict:
    name = ""
    share = ""
    path = ""
    guest = False
    section = ""
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            if section and section.lower() != "global" and not share:
                share = section
            continue
        if "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip().lower()
        val = val.strip()
        if section.lower() == "global" and key == "netbios name":
            name = val
        if section and section.lower() != "global":
            if key == "path" and (section == share or not path):
                path = val
            if key == "guest ok":
                guest = val.lower() in ("yes", "true", "1")
    return {"name": name, "share": share, "path": path, "guest": guest}


def active() -> bool:
    try:
        r = subprocess.run(
            [SYSTEMCTL, "is-active", "--quiet", "smb"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return r.returncode == 0
    except OSError:
        return False


out = missing()
if not SMBD.is_file() and not shutil.which("smbd"):
    print(json.dumps(out, separators=(",", ":")))
    raise SystemExit(0)

out["status"] = "unconfigured"
try:
    text = CONF.read_text(encoding="utf-8", errors="replace")
except OSError:
    print(json.dumps(out, separators=(",", ":")))
    raise SystemExit(0)

fields = parse_conf(text)
out.update(fields)
if fields["path"]:
    out["status"] = "active" if active() else "inactive"
print(json.dumps(out, separators=(",", ":")))
PY
