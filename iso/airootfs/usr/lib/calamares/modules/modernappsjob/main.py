#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Download optional programs the installer page ticked.

Runs on the live system after install.sh, using the target's pacman
database and this machine's network. Nothing in this list is stored
in the ISO.
"""

import os
import subprocess
import sys

sys.path.insert(0, "/usr/lib/modern")
from install_optional import packages_for  # noqa: E402


def _as_list(value):
    if value is None:
        return None
    if isinstance(value, str):
        return [part for part in value.split(",") if part]
    return [str(part) for part in value if str(part)]


def _nvidia_modeset(root, user):
    repo = os.path.join(root, "home", user, "modern_os")
    script = os.path.join(repo, "install/system/nvidia/apply.sh")
    if not user or not os.path.isfile(script):
        return
    subprocess.run(
        [
            "bash",
            "-c",
            'PROVISION_ROOT="$1"; . "$2"; nvidia_apply "$3"',
            "_",
            repo,
            script,
            root,
        ],
        check=False,
    )


def run():
    import libcalamares

    gs = libcalamares.globalstorage
    selected = _as_list(gs.value("modernappsInstall"))
    if not selected:
        return None
    pkgs = packages_for(selected)
    if not pkgs:
        return None
    root = gs.value("rootMountPoint") or ""
    if not root:
        return ("Could not see the installed system", "the selected programs were not downloaded")
    sync = subprocess.run(["pacman", "--sysroot", root, "-Sy", "--noconfirm"])
    if sync.returncode != 0:
        return ("Could not refresh the package lists", " ".join(pkgs))
    proc = subprocess.run(
        ["pacman", "--sysroot", root, "-S", "--needed", "--noconfirm", "--", *pkgs]
    )
    if proc.returncode != 0:
        return ("Could not download a selected program", " ".join(pkgs))
    if "nvidia-proprietary" in selected:
        _nvidia_modeset(root, str(gs.value("username") or ""))
    return None
