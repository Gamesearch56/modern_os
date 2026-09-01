// Installed split: only packages this desktop ships (install/manifests)
// are "system". Leftovers from another session stay removable.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var shipped: ({})
    property bool shippedReady: false

    Process {
        command: [Paths.script("pkg-manifest-names.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._setShipped(this.text)
        }
    }

    function _setShipped(text: string) {
        const next = ({});
        let rows = [];
        try {
            rows = JSON.parse(String(text || "").trim() || "[]");
        } catch (e) {
            rows = [];
        }
        if (!Array.isArray(rows))
            rows = [];
        for (let i = 0; i < rows.length; i++) {
            const n = String(rows[i] || "");
            if (n.length)
                next[n] = true;
        }
        root.shipped = next;
        root.shippedReady = true;
    }

    function inShipped(name: string): bool {
        return !!root.shipped[String(name || "")];
    }

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
        if (!root.inShipped(name))
            return false;
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

    function iconFor(name: string): string {
        const n = String(name || "").toLowerCase();
        if (!n.length)
            return "package-x-generic-symbolic";
        const rules = [
            ["rocm hip cuda nvidia mesa vulkan amdgpu radeon vaapi libva", "video-display"],
            ["linux ucode firmware kernel dkms headers", "cpu"],
            ["pipewire pulse alsa wireplumber sof- jack", "audio-card"],
            ["bluez bluetooth", "bluetooth"],
            ["samba ssh network iwd wpa wget curl wsdd openssh", "network-workgroup"],
            ["snapper restic btrfs timeshift", "document-save"],
            ["stow pacman yay reflector", "system-software-install"],
            ["sudo polkit shadow pam greetd keyring", "security-high"],
            ["sass git gcc clang cmake rust python node gdb jq devel", "applications-development"],
            ["slurp grim swappy hyprpicker wf-recorder", "camera-photo"],
            ["sushi imv preview evince", "image-x-generic"],
            ["nautilus dolphin gvfs thunar xdg-user", "system-file-manager"],
            ["hypr wayland wlroots qt6 gtk quickshell", "preferences-desktop-display"],
            ["font ttf noto inter jetbrains", "preferences-desktop-font"],
            ["base glibc systemd dbus filesystem coreutils", "applications-system"]
        ];
        for (let i = 0; i < rules.length; i++) {
            const keys = rules[i][0].split(" ");
            for (let k = 0; k < keys.length; k++) {
                if (n.indexOf(keys[k]) !== -1)
                    return rules[i][1] + "-symbolic";
            }
        }
        return "package-x-generic-symbolic";
    }
}
