// One curl download. Settings reads the result off Network.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property bool testing: false
    property bool done: false
    property real mbps: 0
    property real bytes: 0
    property real seconds: 0
    property real dnsMs: 0
    property real connectMs: 0
    property int http: 0

    function start() {
        if (root.testing)
            return;
        root.testing = true;
        root.done = false;
        root.mbps = 0;
        root.bytes = 0;
        root.seconds = 0;
        root.dnsMs = 0;
        root.connectMs = 0;
        root.http = 0;
        speedProc.running = true;
    }

    function _parse(text: string) {
        try {
            const obj = JSON.parse((text || "").trim());
            const bps = Number(obj.speed);
            if (!isNaN(bps) && bps > 0)
                root.mbps = bps * 8 / 1000000;
            root.bytes = Number(obj.bytes) || 0;
            root.seconds = Number(obj.time) || 0;
            root.dnsMs = Math.round((Number(obj.dns) || 0) * 1000);
            root.connectMs = Math.round((Number(obj.connect) || 0) * 1000);
            root.http = Number(obj.code) || 0;
            root.done = true;
        } catch (e) {
            Logger.error("Network", String(e));
        }
        root.testing = false;
    }

    Process {
        id: speedProc
        command: ["curl", "-L", "--max-time", "8", "-o", "/dev/null", "-s", "-w", "{\"speed\":%{speed_download},\"bytes\":%{size_download},\"time\":%{time_total},\"dns\":%{time_namelookup},\"connect\":%{time_connect},\"code\":\"%{http_code}\"}", "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
        onExited: {
            if (root.testing)
                root.testing = false;
        }
    }
}
