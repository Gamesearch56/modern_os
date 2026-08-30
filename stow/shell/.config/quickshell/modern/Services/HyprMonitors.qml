// Monitor dump and mode helpers. Hypr.qml owns window/workspace dispatch;
// this type owns `hyprctl -j monitors` so Hypr stays under the line cap.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var host: null
    property var monitorDump: []
    property int monitorGen: 0

    function refreshMonitorDump() {
        dumpProc.running = false;
        Qt.callLater(() => {
            dumpProc.running = true;
        });
    }

    function _ipc(mon: var): var {
        if (!mon)
            return ({});
        const desc = String(mon.description || "");
        const dump = root.monitorDump || [];
        for (let i = 0; i < dump.length; i++) {
            if (String(dump[i].description || "") === desc)
                return dump[i];
        }
        const ipc = mon.lastIpcObject;
        if (ipc && typeof ipc === "object")
            return ipc;
        return ({});
    }

    function parseMode(spec: string): var {
        const s = String(spec || "");
        const m = s.match(/^(\d+)x(\d+)@([\d.]+)/);
        if (!m)
            return null;
        return {
            w: Number(m[1]),
            h: Number(m[2]),
            hz: Number(m[3]),
            mode: m[1] + "x" + m[2] + "@" + m[3]
        };
    }

    function hzFor(mon: var): int {
        const ipc = root._ipc(mon);
        let hz = Number(ipc.refreshRate ?? 0);
        if (!(hz > 1))
            hz = Number(mon?.refreshRate ?? 0);
        if (hz > 1)
            return Math.round(hz);
        const modes = root._modesRaw(mon);
        if (modes.length) {
            const p = root.parseMode(modes[0]);
            return p ? Math.round(p.hz) : 0;
        }
        return 0;
    }

    function _modesRaw(mon: var): var {
        const ipc = root._ipc(mon);
        if (ipc.availableModes && ipc.availableModes.length)
            return ipc.availableModes;
        if (mon && mon.availableModes && mon.availableModes.length)
            return mon.availableModes;
        return [];
    }

    function resolutionsFor(mon: var): var {
        const seen = ({});
        const out = [];
        const modes = root._modesRaw(mon);
        for (let i = 0; i < modes.length; i++) {
            const p = root.parseMode(modes[i]);
            if (!p)
                continue;
            const key = p.w + "x" + p.h;
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({ value: key, titleValue: p.w + " × " + p.h, w: p.w, h: p.h });
        }
        return out;
    }

    function ratesFor(mon: var, w: int, h: int): var {
        const seen = ({});
        const out = [];
        const modes = root._modesRaw(mon);
        for (let i = 0; i < modes.length; i++) {
            const p = root.parseMode(modes[i]);
            if (!p || p.w !== w || p.h !== h)
                continue;
            const key = String(p.hz);
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({
                value: key,
                titleValue: Math.round(p.hz) + " Hz",
                hz: p.hz,
                mode: p.mode
            });
        }
        out.sort((a, b) => b.hz - a.hz);
        return out;
    }

    function bestMode(mon: var, w: int, h: int, preferHz: real): string {
        const rates = root.ratesFor(mon, w, h);
        if (!rates.length)
            return "";
        const want = Number(preferHz);
        for (let i = 0; i < rates.length; i++) {
            if (Math.abs(rates[i].hz - want) < 0.6)
                return rates[i].mode;
        }
        return rates[0].mode;
    }

    function monitorByDesc(desc: string): var {
        const want = String(desc || "");
        const list = root.host ? (root.host.monitors?.values ?? []) : [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].description || "") === want)
                return list[i];
        }
        return null;
    }

    Process {
        id: dumpProc
        running: false
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    root.monitorDump = Array.isArray(j) ? j : [];
                } catch (e) {
                    root.monitorDump = [];
                }
                root.monitorGen++;
            }
        }
    }
}
