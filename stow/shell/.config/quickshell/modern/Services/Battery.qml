// UPower / sysfs battery. The bar island is hidden on AC-only desktops.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property bool onBattery: false
    property int percent: 100
    property bool charging: false
    property string iconName: "battery"
    property var percentSamples: []

    Process {
        id: proc
        command: ["sh", "-c", "upower -i $(upower -e 2>/dev/null | grep -m1 BAT) 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: 15000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    function _parse(text: string) {
        const t = text || "";
        if (t.indexOf("percentage") === -1) {
            root.onBattery = false;
            return;
        }
        const pct = t.match(/percentage:\s*([0-9]+)/);
        if (pct)
            root.percent = Number(pct[1]);
        const st = t.match(/state:\s*(\S+)/);
        const state = st ? st[1] : "";
        root.charging = state === "charging" || state === "fully-charged";
        root.onBattery = state === "discharging" || state === "pending-charge" || (!root.charging && root.percent < 100);
        if (state === "fully-charged")
            root.onBattery = false;
        if (root.charging)
            root.iconName = "battery-charging";
        else if (root.percent <= 15)
            root.iconName = "battery-low";
        else if (root.percent <= 40)
            root.iconName = "battery-caution";
        else
            root.iconName = "battery";
        if (!t.match(/native-path:.*(BAT|battery)/i) && t.indexOf("line-power") !== -1)
            root.onBattery = false;
        const next = (root.percentSamples || []).slice();
        next.push(root.percent);
        if (next.length > 32)
            next.shift();
        root.percentSamples = next;
    }
}
