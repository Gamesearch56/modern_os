// Settings speed test. Several curl streams of the Arch ISO via
// scripts/network-speed.sh so a gigabit link can fill.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property bool testing: false
    property bool done: false
    property bool failed: false
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
        root.failed = false;
        root.mbps = 0;
        root.bytes = 0;
        root.seconds = 0;
        root.dnsMs = 0;
        root.connectMs = 0;
        root.http = 0;
        speedProc.running = true;
    }

    function _parse(text: string) {
        root.testing = false;
        try {
            const obj = JSON.parse((text || "").trim());
            if (obj.ok === false) {
                root.failed = true;
                root.done = false;
                return;
            }
            const bps = Number(obj.speed);
            if (!isNaN(bps) && bps > 0)
                root.mbps = bps * 8 / 1000000;
            root.bytes = Number(obj.bytes) || 0;
            root.seconds = Number(obj.time) || 0;
            root.dnsMs = Math.round((Number(obj.dns) || 0) * 1000);
            root.connectMs = Math.round((Number(obj.connect) || 0) * 1000);
            root.http = Number(obj.code) || 0;
            root.failed = false;
            root.done = true;
        } catch (e) {
            root.failed = true;
            root.done = false;
        }
    }

    Process {
        id: speedProc
        command: [Paths.script("network-speed.sh")]
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
