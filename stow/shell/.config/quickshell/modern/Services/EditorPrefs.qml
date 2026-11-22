pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// Texteditor view preferences in config.json → editor. A change shows at
// once in this window and is written after a short pause, so a run of
// Ctrl+scroll zoom steps is one write instead of one per notch.
Singleton {
    id: root

    readonly property int zoomMin: 50
    readonly property int zoomMax: 300
    readonly property int zoomStep: 10

    property bool wordWrap: Config.editor.wordWrap !== false
    property bool statusBar: Config.editor.statusBar !== false
    property bool monospace: Config.editor.monospace !== false
    property int zoom: root._clamp(Config.editor.zoom ?? 100)

    property var _pending: ({})

    function _clamp(value: real): int {
        const v = Math.round(Number(value) || 100);
        return Math.max(root.zoomMin, Math.min(root.zoomMax, v));
    }

    function _keep(name: string, value: var) {
        const next = Object.assign({}, root._pending);
        next[name] = value;
        root._pending = next;
        writeSoon.restart();
    }

    function setWordWrap(on: bool) {
        root.wordWrap = on;
        root._keep("wordWrap", on);
    }

    function setStatusBar(on: bool) {
        root.statusBar = on;
        root._keep("statusBar", on);
    }

    function setMonospace(on: bool) {
        root.monospace = on;
        root._keep("monospace", on);
    }

    function setZoom(value: real) {
        const v = root._clamp(value);
        if (v === root.zoom)
            return;
        root.zoom = v;
        root._keep("zoom", v);
    }

    function zoomBy(steps: int) {
        root.setZoom(root.zoom + steps * root.zoomStep);
    }

    function flush() {
        writeSoon.stop();
        const pending = root._pending;
        root._pending = ({});
        for (const name in pending)
            ConfigWrite.set("editor." + name, pending[name]);
    }

    Timer {
        id: writeSoon
        interval: Motion.configWriteMs
        onTriggered: root.flush()
    }
}
