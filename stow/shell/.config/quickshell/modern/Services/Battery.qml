// UPower / sysfs battery. The bar island is hidden on AC-only desktops.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property bool hasBattery: false
    property bool onBattery: false
    property int percent: 100
    property bool charging: false
    property string iconName: "battery"
    property var percentSamples: []
    property int timeSeconds: 0
    property bool timeToFull: false
    property real rateWatts: 0

    readonly property string timeLabel: {
        if (root.timeSeconds <= 0)
            return "";
        const mins = Math.max(1, Math.round(root.timeSeconds / 60));
        const hours = mins >= 120;
        const n = hours ? Math.round(mins / 60) : mins;
        let key = "";
        if (root.timeToFull)
            key = hours ? "settings.energy.untilFullHours" : "settings.energy.untilFullMin";
        else
            key = hours ? "settings.energy.remainingHours" : "settings.energy.remainingMin";
        return I18n.t(key, ({ n: n }));
    }

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

    function _parseDuration(s: string): int {
        const t = String(s || "").trim().toLowerCase();
        if (t.length === 0 || t.indexOf("unknown") >= 0)
            return 0;
        const n = parseFloat(t);
        if (n !== n)
            return 0;
        if (t.indexOf("hour") >= 0)
            return Math.round(n * 3600);
        if (t.indexOf("minute") >= 0)
            return Math.round(n * 60);
        if (t.indexOf("second") >= 0)
            return Math.round(n);
        return 0;
    }

    function _clear() {
        root.hasBattery = false;
        root.onBattery = false;
        root.charging = false;
        root.timeSeconds = 0;
        root.timeToFull = false;
        root.rateWatts = 0;
        root.percentSamples = [];
        root.iconName = "ac-adapter";
    }

    function _parse(text: string) {
        const t = text || "";
        if (t.indexOf("percentage") === -1) {
            root._clear();
            return;
        }
        root.hasBattery = true;
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
        if (!t.match(/native-path:.*(BAT|battery)/i) && t.indexOf("line-power") !== -1) {
            root._clear();
            return;
        }
        const empty = t.match(/time to empty:\s*(.+)/i);
        const full = t.match(/time to full:\s*(.+)/i);
        if (full && root.charging) {
            root.timeSeconds = root._parseDuration(full[1]);
            root.timeToFull = true;
        } else if (empty) {
            root.timeSeconds = root._parseDuration(empty[1]);
            root.timeToFull = false;
        } else {
            root.timeSeconds = 0;
            root.timeToFull = false;
        }
        const rate = t.match(/energy-rate:\s*([0-9.]+)/i);
        root.rateWatts = rate ? Number(rate[1]) : 0;
        const next = (root.percentSamples || []).slice();
        next.push(root.percent);
        if (next.length > 32)
            next.shift();
        root.percentSamples = next;
    }
}
