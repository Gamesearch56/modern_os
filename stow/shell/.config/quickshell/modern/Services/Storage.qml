// Disk usage, block devices, eject. One poller while Settings → Storage
// is visible.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property var mounts: []
    property var devices: []

    Process {
        id: dfProc
        command: ["sh", "-c", "df -P -B1 --output=source,fstype,size,used,avail,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR>1{print}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseDf(this.text)
        }
    }

    Process {
        id: lsblkProc
        command: ["lsblk", "-J", "-o", "NAME,TYPE,SIZE,TRAN,RM,MOUNTPOINT,MODEL"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseLsblk(this.text)
        }
    }

    Timer {
        interval: 5000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            dfProc.running = true;
            lsblkProc.running = true;
        }
    }

    function formatBytes(n: real): string {
        const v = Number(n) || 0;
        if (v >= 1e12)
            return (v / 1e12).toFixed(1) + " TB";
        if (v >= 1e9)
            return (v / 1e9).toFixed(1) + " GB";
        if (v >= 1e6)
            return (v / 1e6).toFixed(1) + " MB";
        if (v >= 1e3)
            return (v / 1e3).toFixed(1) + " KB";
        return String(Math.round(v)) + " B";
    }

    function eject(name: string) {
        if (!name)
            return;
        Quickshell.execDetached(["udisksctl", "unmount", "-b", "/dev/" + name]);
        Quickshell.execDetached(["udisksctl", "power-off", "-b", "/dev/" + name]);
    }

    function _parseDf(text: string) {
        const lines = (text || "").trim().split("\n");
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            const c = lines[i].trim().split(/\s+/);
            if (c.length < 6)
                continue;
            const size = Number(c[2]);
            const used = Number(c[3]);
            out.push({
                source: c[0],
                fstype: c[1],
                size: size,
                used: used,
                avail: Number(c[4]),
                target: c.slice(5).join(" "),
                usedLabel: root.formatBytes(used),
                freeLabel: root.formatBytes(Number(c[4])),
                sizeLabel: root.formatBytes(size)
            });
        }
        root.mounts = out;
    }

    function _parseLsblk(text: string) {
        try {
            const j = JSON.parse(text);
            root.devices = j.blockdevices || [];
        } catch (e) {
            Logger.warn("Storage", String(e));
        }
    }
}
