// UPower via battery-read.sh. The bar island is hidden on AC-only
// desktops, not while a laptop pack is charging.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property int _watchers: 0
    readonly property bool watching: root._watchers > 0
    property bool hasBattery: false
    property bool onBattery: false
    property int percent: 100
    property bool charging: false
    property var percentSamples: []
    property int timeSeconds: 0
    property bool timeToFull: false
    property real rateWatts: 0

    readonly property string iconName: {
        if (!root.hasBattery)
            return "battery-missing-symbolic";
        const step = Math.round(Math.max(0, Math.min(100, root.percent)) / 10) * 10;
        if (root.charging && root.percent >= 99)
            return "battery-level-100-charged-symbolic";
        if (root.charging)
            return "battery-level-" + step + "-charging-symbolic";
        return "battery-level-" + step + "-symbolic";
    }

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

    function watch() {
        root._watchers += 1;
    }

    function unwatch() {
        root._watchers = Math.max(0, root._watchers - 1);
    }

    function _clear() {
        root.hasBattery = false;
        root.onBattery = false;
        root.charging = false;
        root.timeSeconds = 0;
        root.timeToFull = false;
        root.rateWatts = 0;
        root.percentSamples = [];
    }

    function _parse(text: string) {
        try {
            const obj = JSON.parse((text || "").trim() || "{}");
            if (!obj.hasBattery) {
                root._clear();
                return;
            }
            root.hasBattery = true;
            root.percent = Number(obj.percent) || 0;
            root.charging = !!obj.charging;
            root.onBattery = !!obj.onBattery;
            root.timeSeconds = Number(obj.timeSeconds) || 0;
            root.timeToFull = !!obj.timeToFull;
            root.rateWatts = Number(obj.rateWatts) || 0;
            const next = (root.percentSamples || []).slice();
            next.push(root.percent);
            if (next.length > 32)
                next.shift();
            root.percentSamples = next;
        } catch (e) {
            Logger.error("Battery", String(e));
            root._clear();
        }
    }

    Process {
        id: proc
        command: [Paths.script("battery-read.sh")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: Motion.processWatchMs
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
