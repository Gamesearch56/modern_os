// Folder totals. A saved total is reused, so this walk and the loading
// bar run only after that save is gone or the folder itself changed.
// Storage cleanup deletes the save.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string folder: ""
    readonly property bool running: proc.running

    property var _bag: ({})
    property bool _dirty: false

    signal batch(string folder, var sizes)

    function start(folder: string, hidden: bool) {
        const path = String(folder || "");
        if (!path.length) {
            root.stop();
            return;
        }
        root.stop();
        root.folder = path;
        root._bag = ({});
        root._dirty = false;
        proc.command = [
            Paths.script("files-ops.sh"), "sizes", path, hidden ? "1" : "0"
        ];
        proc.running = true;
    }

    function stop() {
        flush.stop();
        root._bag = ({});
        root._dirty = false;
        proc.running = false;
    }

    function _note(line: string) {
        const text = String(line || "").trim();
        if (!text.length || !root.folder.length)
            return;
        let row = null;
        try { row = JSON.parse(text); } catch (e) { return; }
        if (!row || !row.path)
            return;
        root._bag[row.path] = row.size;
        root._dirty = true;
        if (!flush.running)
            flush.start();
    }

    function _flush() {
        if (!root._dirty)
            return;
        const folder = root.folder;
        const bag = root._bag;
        root._bag = ({});
        root._dirty = false;
        root.batch(folder, bag);
    }

    Timer {
        id: flush
        interval: Motion.mediumMs
        onTriggered: root._flush()
    }

    Process {
        id: proc
        running: false
        stdout: SplitParser { onRead: line => root._note(line) }
        onExited: root._flush()
    }
}
