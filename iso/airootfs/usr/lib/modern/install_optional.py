"""Optional programs the installer downloads only when ticked.

Vivaldi, the open firmware and the desktop are not here. They are
installed with the system. A ticked name becomes pacman package names.
The NVIDIA entry is the proprietary driver, not nouveau. Battle.net is
not a package: the tick downloads Blizzard's setup into the new
account, and the first launch runs that file.
"""

import os
import subprocess

CHOICES = {
    "steam": ("steam",),
    "spotify-launcher": ("spotify-launcher",),
    "discord": ("discord",),
    "proton-vpn-gtk-app": ("proton-vpn-gtk-app",),
    "nvidia-proprietary": ("nvidia-open-dkms", "nvidia-utils"),
}

BATTLENET = "battlenet"
BATTLENET_URL = (
    "https://downloader.battle.net/download/getInstaller"
    "?os=win&installer=Battle.net-Setup.exe"
)


def packages_for(selected):
    """Pacman names for the ticked ids, in a stable order."""
    chosen = list(selected or [])
    out = []
    seen = set()
    for key in ("nvidia-proprietary", "steam", "spotify-launcher", "discord", "proton-vpn-gtk-app"):
        if key not in chosen:
            continue
        names = list(CHOICES[key])
        if key == "steam" and "nvidia-proprietary" in chosen:
            names.append("lib32-nvidia-utils")
        for name in names:
            if name not in seen:
                seen.add(name)
                out.append(name)
    return out


def wants_battlenet(selected):
    return BATTLENET in list(selected or [])


def _ids(root, user):
    path = os.path.join(root, "etc", "passwd")
    try:
        lines = open(path, encoding="utf-8", errors="replace")
    except OSError:
        return None
    with lines as handle:
        for line in handle:
            parts = line.rstrip("\n").split(":")
            if len(parts) > 3 and parts[0] == user:
                try:
                    return int(parts[2]), int(parts[3])
                except ValueError:
                    return None
    return None


def fetch_battlenet(root, user, run=None):
    """Download Battle.net's setup into the new account's cache.

    Returns None, or a (title, detail) pair the installer can show.
    `run` is the process starter, so a test can avoid the network.
    """
    if not root or not user or "/" in user or user in (".", ".."):
        return ("Could not download Battle.net", "the new account is not ready")
    ids = _ids(root, user)
    if ids is None:
        return ("Could not download Battle.net", "the new account is not ready")
    cache = os.path.join(root, "home", user, ".cache", "modern")
    dest = os.path.join(cache, "Battle.net-Setup.exe")
    if os.path.isfile(dest) and os.path.getsize(dest) > 0:
        return None
    os.makedirs(cache, mode=0o700, exist_ok=True)
    part = dest + ".part"
    starter = run or subprocess.run
    proc = starter(
        ["curl", "-fsSL", "--max-time", "300", "-o", part, BATTLENET_URL],
    )
    if getattr(proc, "returncode", 1) != 0 or not os.path.isfile(part):
        try:
            os.remove(part)
        except OSError:
            pass
        return ("Could not download Battle.net", "check the network and try again")
    os.replace(part, dest)
    uid, gid = ids
    owned = os.geteuid() == 0
    for path, mode in (
        (os.path.join(root, "home", user, ".cache"), 0o700),
        (cache, 0o700),
        (dest, 0o644),
    ):
        if owned:
            os.chown(path, uid, gid)
        os.chmod(path, mode)
    return None
