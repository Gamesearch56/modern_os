pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Imageviewer preferences in config.json → viewer. A change shows at once
// and is written after a short pause, like EditorPrefs.
//   scaling: "shrink" (fit, never enlarge), "fit" (fill the window),
//            "actual" (one image pixel per screen pixel)
Singleton {
    id: root

    readonly property var scalings: ["shrink", "fit", "actual"]
    readonly property int slideshowMin: 1
    readonly property int slideshowMax: 60

    property string scaling: root.scalings.indexOf(Config.viewer.scaling) >= 0 ? Config.viewer.scaling : "shrink"
    property bool info: Config.viewer.info === true
    readonly property int slideshowSeconds: Math.max(root.slideshowMin,
        Math.min(root.slideshowMax, Math.round(Number(Config.viewer.slideshowSeconds) || 4)))

    property var _pending: ({})

    function _keep(name: string, value: var) {
        const next = Object.assign({}, root._pending);
        next[name] = value;
        root._pending = next;
        writeSoon.restart();
    }

    function setScaling(mode: string) {
        if (root.scalings.indexOf(mode) < 0)
            return;
        root.scaling = mode;
        root._keep("scaling", mode);
    }

    function nextScaling() {
        const i = root.scalings.indexOf(root.scaling);
        root.setScaling(root.scalings[(i + 1) % root.scalings.length]);
    }

    function setInfo(on: bool) {
        root.info = on;
        root._keep("info", on);
    }

    function flush() {
        writeSoon.stop();
        const pending = root._pending;
        root._pending = ({});
        for (const name in pending)
            ConfigWrite.set("viewer." + name, pending[name]);
    }

    Timer {
        id: writeSoon
        interval: Motion.configWriteMs
        onTriggered: root.flush()
    }
}
