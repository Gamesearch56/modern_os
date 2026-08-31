// One dry-run palette per matugen scheme, from the current wallpaper
// and light/dark mode. Theme.selectSpec / applySeed writes the choice.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var palettes: []
    property bool loading: false
    property var _queued: null
    property string key: ""
    property string _inflight: ""

    readonly property bool busy: previewProc.running || root._queued !== null

    function refresh(wallpaper: string, mode: string) {
        const wp = String(wallpaper || "");
        let m = String(mode || "dark");
        if (m !== "light")
            m = "dark";
        const spec = { path: wp, mode: m };
        const next = wp + "|" + m;
        if (!wp.length) {
            root.palettes = [];
            root.key = "";
            root._inflight = "";
            return;
        }
        if (next === root.key && root.palettes.length > 0 && !previewProc.running)
            return;
        if (next === root._inflight && previewProc.running)
            return;
        if (previewProc.running) {
            root._queued = spec;
            return;
        }
        root._start(spec);
    }

    function _start(spec: var) {
        root._inflight = spec.path + "|" + spec.mode;
        root.loading = true;
        previewProc.command = [
            Paths.script("theme-previews.sh"),
            "--wallpaper", spec.path,
            "--mode", spec.mode
        ];
        previewProc.running = true;
    }

    Process {
        id: previewProc
        running: false
        stdout: StdioCollector {
            id: previewOut
        }
        onExited: (code) => {
            const run = root._inflight;
            const next = root._queued;
            root._queued = null;
            if (code === 0) {
                try {
                    const parsed = JSON.parse(previewOut.text.trim() || "[]");
                    root.palettes = Array.isArray(parsed) ? parsed : [];
                    root.key = run;
                } catch (e) {
                    root.palettes = [];
                }
            } else {
                root.palettes = [];
            }
            root.loading = false;
            root._inflight = "";
            if (next)
                Qt.callLater(() => root._start(next));
        }
    }
}
