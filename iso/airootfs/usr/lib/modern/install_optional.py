"""Optional programs the installer downloads only when ticked.

Vivaldi, the open firmware and the desktop are not here. They are
installed with the system. A ticked name becomes pacman package names.
The NVIDIA entry is the proprietary driver, not nouveau.
"""

CHOICES = {
    "steam": ("steam",),
    "spotify-launcher": ("spotify-launcher",),
    "discord": ("discord",),
    "proton-vpn-gtk-app": ("proton-vpn-gtk-app",),
    "nvidia-proprietary": ("nvidia-open-dkms", "nvidia-utils"),
}


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
