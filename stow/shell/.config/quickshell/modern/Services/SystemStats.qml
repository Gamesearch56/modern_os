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
    property int fanRpm: 0
    property int fanRpmPeak: 1
    readonly property real fanPercent: 100 * root.fanRpm / Math.max(1, root.fanRpmPeak)

    property var _prev: ({ idle: 0, total: 0 })
    property var cpuSamples: []
    property var ramSamples: []
    property var diskSamples: []

    Process {
        id: proc
        command: ["sh", "-c", "grep -m1 '^cpu ' /proc/stat; awk '/MemTotal/{t=$2}/MemAvailable/{a=$2} END{print t,a}' /proc/meminfo; df -P -k / | awk 'NR==2{print $2,$3}'; (cat /sys/class/drm/card*/device/gpu_busy_percent /sys/class/drm/card*/gt/gt0/busy_percent 2>/dev/null | head -1; nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null; echo 0) | awk 'NF{print $1; exit}'; (cat /sys/class/hwmon/hwmon*/fan*_input 2>/dev/null || echo 0) | awk 'NR==1{print $1+0}'"]
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
            const gpu = Number((lines[3] ?? "").trim().split(/\s+/)[0]);
            if (!isNaN(gpu))
                root.gpuPercent = gpu;
            const fan = Number((lines[4] ?? "").trim());
            if (!isNaN(fan)) {
                root.fanRpm = fan;
                if (fan > root.fanRpmPeak)
                    root.fanRpmPeak = fan;
            }
            root.cpuSamples = root._push(root.cpuSamples, root.cpuPercent);
            root.ramSamples = root._push(root.ramSamples, root.ramPercent);
            root.diskSamples = root._push(root.diskSamples, root.diskPercent);
        } catch (e) {
            Logger.warn("SystemStats", String(e));
        }
    }

    function _push(arr: var, v: real): var {
        const next = (arr || []).slice();
        next.push(v);
        if (next.length > 32)
            next.shift();
        return next;
    }
}
