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
    property int timeEmptySeconds: 0
    property int timeFullSeconds: 0
    property real rateWatts: 0
    property real energyWh: 0
    property real energyFullWh: 0
    property int healthPercent: 0
    property real voltage: 0
    property int cycles: -1

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

    readonly property bool full: root.hasBattery && root.charging && root.percent >= 99
    readonly property string remainingLabel: root.formatDuration(root.timeEmptySeconds)
    readonly property string untilFullLabel: root.formatDuration(root.timeFullSeconds)
    readonly property string timeLabel: {
        if (root.timeToFull)
            return root._span(root.timeFullSeconds, true);
        return root._span(root.timeEmptySeconds, false);
    }

    function watch() {
        root._watchers += 1;
    }

    function unwatch() {
        root._watchers = Math.max(0, root._watchers - 1);
    }

    function formatDuration(sec: int): string {
        if (sec <= 0)
            return "";
        const mins = Math.max(1, Math.round(sec / 60));
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        if (h > 0 && m > 0)
            return I18n.t("settings.energy.durationHm", ({ h: h, m: m }));
        if (h > 0)
            return I18n.t("settings.energy.durationH", ({ n: h }));
        return I18n.t("settings.energy.durationM", ({ n: m }));
    }

    function formatWh(n: real): string {
        return String(Math.round(Number(n) * 10) / 10);
    }

    function _span(sec: int, full: bool): string {
        if (sec <= 0)
            return "";
        const mins = Math.max(1, Math.round(sec / 60));
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        if (h > 0 && m > 0)
            return I18n.t(full ? "settings.energy.untilFullHm" : "settings.energy.remainingHm", ({ h: h, m: m }));
        if (h > 0)
            return I18n.t(full ? "settings.energy.untilFullHours" : "settings.energy.remainingHours", ({ n: h }));
        return I18n.t(full ? "settings.energy.untilFullMin" : "settings.energy.remainingMin", ({ n: m }));
    }

    function _clear() {
        root.hasBattery = false;
        root.onBattery = false;
        root.charging = false;
        root.timeSeconds = 0;
        root.timeToFull = false;
        root.timeEmptySeconds = 0;
        root.timeFullSeconds = 0;
        root.rateWatts = 0;
        root.energyWh = 0;
        root.energyFullWh = 0;
        root.healthPercent = 0;
        root.voltage = 0;
        root.cycles = -1;
        root.percentSamples = [];
    }

    function _parse(text: string) {
        const raw = (text || "").trim();
        if (!raw.length)
            return;
        try {
            const obj = JSON.parse(raw);
            if (!obj.hasBattery) {
                // A missed poll must not hide a pack this session already saw.
                if (!root.hasBattery)
                    root._clear();
                return;
            }
            root.hasBattery = true;
            root.percent = Number(obj.percent) || 0;
            root.charging = !!obj.charging;
            root.onBattery = !!obj.onBattery;
            root.timeEmptySeconds = Number(obj.timeEmptySeconds) || 0;
            root.timeFullSeconds = Number(obj.timeFullSeconds) || 0;
            root.timeToFull = !!obj.timeToFull;
            root.timeSeconds = Number(obj.timeSeconds) || (root.timeToFull ? root.timeFullSeconds : root.timeEmptySeconds);
            root.rateWatts = Number(obj.rateWatts) || 0;
            root.energyWh = Number(obj.energyWh) || 0;
            root.energyFullWh = Number(obj.energyFullWh) || 0;
            root.healthPercent = Number(obj.healthPercent) || 0;
            root.voltage = Number(obj.voltage) || 0;
            root.cycles = (obj.cycles === 0 || obj.cycles > 0) ? Number(obj.cycles) : -1;
            const next = (root.percentSamples || []).slice();
            next.push(root.percent);
            if (next.length > 32)
                next.shift();
            root.percentSamples = next;
        } catch (e) {
            Logger.error("Battery", String(e));
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
        onTriggered: {
            if (!proc.running)
                proc.running = true;
        }
    }
}
