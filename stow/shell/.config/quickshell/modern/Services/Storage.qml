// Disk inventory, usage, link speed, and eject. One poller while
// Settings → Storage is visible. Never calls lsblk from a Module.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property string ejecting: ""
    property var internal: []
    property var external: []
    property var _speeds: ({})
    property string _lsblkText: ""

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,TYPE,SIZE,TRAN,RM,HOTPLUG,ROTA,MODEL,SERIAL,VENDOR,FSTYPE,FSSIZE,FSUSED,FSAVAIL,MOUNTPOINT,LABEL"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseLsblk(this.text)
        }
    }

    Process {
        id: speedProc
        command: ["sh", "-c", "for b in /sys/block/*; do n=${b##*/}; spd=; case $n in nvme*) c=${n%n*}; if [ -f /sys/class/nvme/$c/device/current_link_speed ]; then spd=$(tr -d '\\n' </sys/class/nvme/$c/device/current_link_speed); w=$(tr -d '\\n' </sys/class/nvme/$c/device/current_link_width); spd=\"$spd|$w\"; fi;; esac; if [ -z \"$spd\" ]; then cur=$(readlink -f \"$b\"); while [ \"$cur\" != / ]; do if [ -f \"$cur/idVendor\" ] && [ -f \"$cur/speed\" ]; then spd=$(tr -d '\\n' <\"$cur/speed\"); break; fi; cur=$(dirname \"$cur\"); done; fi; printf '%s\\t%s\\n' \"$n\" \"$spd\"; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseSpeeds(this.text)
        }
    }

    Process {
        id: ejectProc
        command: ["sh", "-c", "dev=/dev/$1; for p in $(lsblk -ln -o NAME,TYPE \"$dev\" | awk '$2==\"part\"{print $1}'); do mp=$(lsblk -ln -n -o MOUNTPOINT \"/dev/$p\"); if [ -n \"$mp\" ]; then udisksctl unmount -b \"/dev/$p\" || true; fi; done; udisksctl power-off -b \"$dev\" || true", "eject", root.ejecting]
        running: false
        onExited: {
            root.ejecting = "";
            if (root.watching) {
                lsblkProc.running = true;
                speedProc.running = true;
            }
        }
    }

    Timer {
        interval: 5000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            lsblkProc.running = true;
            speedProc.running = true;
        }
    }

    function formatBytes(n: real): string {
        const v = Number(n) || 0;
        if (v >= 1e12)
            return I18n.t("units.tb", { n: (v / 1e12).toFixed(1) });
        if (v >= 1e9)
            return I18n.t("units.gb", { n: (v / 1e9).toFixed(1) });
        if (v >= 1e6)
            return I18n.t("units.mb", { n: (v / 1e6).toFixed(1) });
        if (v >= 1e3)
            return I18n.t("units.kb", { n: (v / 1e3).toFixed(1) });
        return I18n.t("units.b", { n: Math.round(v) });
    }

    function eject(name: string) {
        const n = String(name || "").replace(/[^A-Za-z0-9]/g, "");
        if (!n || root.ejecting.length)
            return;
        root.ejecting = n;
        ejectProc.running = true;
    }

    function _skip(d: var): bool {
        const n = String(d.name || "");
        const t = String(d.type || "");
        if (t !== "disk")
            return true;
        if (n.indexOf("loop") === 0 || n.indexOf("zram") === 0 || n.indexOf("ram") === 0)
            return true;
        return false;
    }

    function _isExternal(d: var): bool {
        const t = String(d.tran || "").toLowerCase();
        if (t === "usb" || t === "ieee1394" || t === "sbp2" || t === "firewire")
            return true;
        return d.rm === true || d.rm === "1";
    }

    function _walkUsage(node: var, acc: var) {
        const kids = node.children || [];
        if (kids.length) {
            for (let i = 0; i < kids.length; i++)
                root._walkUsage(kids[i], acc);
            return;
        }
        const fs = Number(node.fssize);
        if (fs > 0) {
            const key = String(node.label || node.path || fs);
            if (!acc.seen[key]) {
                acc.seen[key] = true;
                acc.fsSize += fs;
                acc.used += Number(node.fsused) || 0;
                acc.avail += Number(node.fsavail) || 0;
                if (fs >= acc.bestFs && node.fstype) {
                    acc.bestFs = fs;
                    acc.fstype = String(node.fstype);
                }
            }
        } else if (node.fstype && !acc.fstype)
            acc.fstype = String(node.fstype);
        const mp = String(node.mountpoint || "");
        if (mp.indexOf("/") === 0)
            acc.mounts.push(mp);
    }

    function _normalize(d: var): var {
        const acc = { seen: ({}), fsSize: 0, used: 0, avail: 0, fstype: "", mounts: [], bestFs: 0 };
        root._walkUsage(d, acc);
        const external = root._isExternal(d);
        const rota = d.rota === true || d.rota === "1";
        const name = String(d.name || "");
        return {
            name: name,
            title: String(d.model || name).trim(),
            serial: String(d.serial || "").trim(),
            tran: String(d.tran || "").toLowerCase(),
            external: external,
            rota: rota,
            size: Number(d.size) || 0,
            fsSize: acc.fsSize,
            used: acc.used,
            avail: acc.avail,
            fstype: acc.fstype,
            mount: acc.mounts.length ? acc.mounts[0] : "",
            speedRaw: root._speeds[name] || "",
            iconName: external ? "drive-removable-media" : "drive-harddisk"
        };
    }

    function _parseSpeeds(text: string) {
        const map = {};
        const lines = (text || "").trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].split("\t");
            if (p.length >= 2)
                map[p[0]] = p[1];
        }
        root._speeds = map;
        if (root._lsblkText.length)
            root._parseLsblk(root._lsblkText);
    }

    function _parseLsblk(text: string) {
        root._lsblkText = text || "";
        try {
            const j = JSON.parse(text);
            const list = j.blockdevices || [];
            const intern = [];
            const extern = [];
            for (let i = 0; i < list.length; i++) {
                if (root._skip(list[i]))
                    continue;
                const d = root._normalize(list[i]);
                if (d.external)
                    extern.push(d);
                else
                    intern.push(d);
            }
            root.internal = intern;
            root.external = extern;
        } catch (e) {
            Logger.warn("Storage", String(e));
        }
    }
}
