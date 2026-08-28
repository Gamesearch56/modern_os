// Shared sensor poller. The only timer that reads /proc and hwmon —
// performance widgets bind here and the timer stops when `watching`
// is false (no consumer visible).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property real cpuPercent: 0
    property real ramPercent: 0
    property real gpuPercent: 0
    property real cpuTemp: 0
    property real gpuTemp: 0
    property real diskPercent: 0

    property var _prev: ({ idle: 0, total: 0 })

    Process {
        id: proc
        command: ["sh", "-c", "grep -m1 '^cpu ' /proc/stat; awk '/MemTotal/{t=$2}/MemAvailable/{a=$2} END{print t,a}' /proc/meminfo; df -P -k / | awk 'NR==2{print $2,$3}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: Config.widgets.performance?.pollIntervalMs ?? 2000
        running: root.watching
        repeat: true
        onTriggered: proc.running = true
    }

    function _parse(text: string) {
        try {
            const lines = text.trim().split("\n");
            const cpu = (lines[0] ?? "").trim().split(/\s+/);
            if (cpu.length >= 5) {
                const user = Number(cpu[1]) + Number(cpu[2]) + Number(cpu[3]);
                const idle = Number(cpu[4]);
                const total = user + idle;
                const dTotal = total - root._prev.total;
                const dIdle = idle - root._prev.idle;
                if (dTotal > 0)
                    root.cpuPercent = 100 * (1 - dIdle / dTotal);
                root._prev = { idle: idle, total: total };
            }
            const mem = (lines[1] ?? "").trim().split(/\s+/);
            const t = Number(mem[0]);
            const a = Number(mem[1]);
            if (t > 0)
                root.ramPercent = 100 * (1 - a / t);
            const disk = (lines[2] ?? "").trim().split(/\s+/);
            const dt = Number(disk[0]);
            const du = Number(disk[1]);
            if (dt > 0)
                root.diskPercent = 100 * (du / dt);
        } catch (e) {
            Logger.warn("SystemStats", String(e));
        }
    }
}
