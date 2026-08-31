// Unique palettes matugen can extract from the current wallpaper.
// Dry-run only — Theme.applySeed writes the chosen seed.
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
    property string _key: ""

    readonly property bool busy: previewProc.running || root._queued !== null

    function refresh(wallpaper: string, variant: string, mode: string) {
        const wp = String(wallpaper || "");
        const v = String(variant || "tonal-spot");
        let m = String(mode || "dark");
        if (m !== "light")
            m = "dark";
        const spec = { path: wp, variant: v, mode: m };
        const key = wp + "|" + v + "|" + m;
        if (!wp.length) {
            root.palettes = [];
            root._key = "";
            return;
        }
        if (key === root._key && previewProc.running)
            return;
        if (previewProc.running) {
            root._queued = spec;
            return;
        }
        root._start(spec);
    }

    function _start(spec: var) {
        root._key = spec.path + "|" + spec.variant + "|" + spec.mode;
        root.loading = true;
        previewProc.command = [
            Paths.script("theme-previews.sh"),
            "--wallpaper", spec.path,
            "--variant", spec.variant,
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
            const next = root._queued;
            root._queued = null;
            if (code === 0) {
                try {
                    const parsed = JSON.parse(previewOut.text.trim() || "[]");
                    root.palettes = Array.isArray(parsed) ? parsed : [];
                } catch (e) {
                    root.palettes = [];
                }
            } else {
                root.palettes = [];
            }
            root.loading = false;
            if (next)
                Qt.callLater(() => root._start(next));
        }
    }
}
