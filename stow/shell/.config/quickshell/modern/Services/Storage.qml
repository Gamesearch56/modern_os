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

    readonly property var systemDrive: {
        const list = root.internal || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].system)
                return list[i];
        }
        return list.length ? list[0] : ({});
    }
    readonly property var otherInternal: {
        const list = root.internal || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (!list[i].system)
                out.push(list[i]);
        }
        return out;
    }

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,TYPE,SIZE,TRAN,RM,HOTPLUG,ROTA,MODEL,SERIAL,VENDOR,FSTYPE,FSSIZE,FSUSED,FSAVAIL,MOUNTPOINT,MOUNTPOINTS,LABEL"]
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

    function openMount(path: string) {
        const p = String(path || "");
        if (p.charAt(0) !== "/")
            return;
        Quickshell.execDetached(["xdg-open", p]);
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
                if (parse.skip(list[i]))
                    continue;
                const d = parse.normalize(list[i], root._speeds);
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

    StorageParse {
        id: parse
    }
}
