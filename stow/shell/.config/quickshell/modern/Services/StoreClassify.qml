// Names pacman HoldPkg does not fully cover — keep in sync with
// scripts/lib/pkg-name.sh. Removing these bricks the session.
import Quickshell
import QtQuick

QtObject {
    id: root

    function isProtected(name: string): bool {
        const n = String(name || "");
        return "pacman pacman-mirrorlist archlinux-keyring glibc gcc-libs filesystem linux linux-lts linux-zen linux-firmware systemd systemd-libs dbus util-linux coreutils bash shadow sudo polkit base hyprland quickshell".split(" ").indexOf(n) !== -1;
    }

    function inCatalog(name: string, categories): bool {
        const n = String(name || "");
        const cats = categories || [];
        for (let i = 0; i < cats.length; i++) {
            const id = String(cats[i] && cats[i].id || "");
            if (id === "discover" || id === "installed")
                continue;
            const pkgs = cats[i].packages || [];
            for (let j = 0; j < pkgs.length; j++) {
                if (String(pkgs[j] || "") === n)
                    return true;
            }
        }
        return false;
    }

    function hasDesktop(name: string): bool {
        const n = String(name || "").toLowerCase();
        if (!n.length)
            return false;
        const stems = [n];
        const cut = n.replace(/-git$/, "").replace(/-bin$/, "").replace(/-desktop$/, "")
            .replace(/-gtk$/, "").replace(/-qt$/, "").replace(/-fresh$/, "");
        if (cut !== n && cut.length)
            stems.push(cut);
        try {
            const entries = DesktopEntries.applications.values;
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                const id = String(e.id || "").replace(/\.desktop$/i, "").toLowerCase();
                const last = id.indexOf(".") >= 0 ? id.substring(id.lastIndexOf(".") + 1) : id;
                const icon = String(e.icon || "").toLowerCase();
                for (let s = 0; s < stems.length; s++) {
                    const stem = stems[s];
                    if (id === stem || last === stem || icon === stem)
                        return true;
                }
            }
        } catch (err) {
        }
        return false;
    }

    function isSystem(name: string, categories): bool {
        if (root.isProtected(name))
            return true;
        if (root.inCatalog(name, categories))
            return false;
        return !root.hasDesktop(name);
    }

    function splitInstalled(rows, categories) {
        const apps = [];
        const system = [];
        const list = rows || [];
        for (let i = 0; i < list.length; i++) {
            const row = list[i];
            const n = String(row && row.name || "");
            if (!n.length)
                continue;
            if (root.isSystem(n, categories))
                system.push(row);
            else
                apps.push(row);
        }
        return { apps: apps, system: system };
    }
}
