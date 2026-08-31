// Disk JPEG thumbs for wallpaper tiles. Owns the cache process; the
// Wallpaper singleton exposes tileSource() so Modules never spawn it.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property var map: ({})
    property int rev: 0
    property var _paths: []
    property var _buf: ({})

    function url(path: string): string {
        void root.rev;
        const p = String(path || "");
        if (!p.length)
            return "";
        const t = root.map[p];
        if (typeof t === "string" && t.length > 0)
            return "file://" + t;
        return "file://" + p;
    }

    function rebuild(paths) {
        const list = Array.isArray(paths)
            ? paths.map(p => String(p || "")).filter(p => p.length > 0)
            : [];
        root._paths = list;
        proc.running = false;
        if (list.length === 0)
            return;
        Qt.callLater(() => {
            proc.command = [Paths.script("wallpaper-thumbs.sh")].concat(root._paths);
            proc.running = true;
        });
    }

    function _ingest(line: string) {
        const t = String(line || "");
        const i = t.indexOf("\t");
        if (i <= 0)
            return;
        const src = t.slice(0, i);
        const dest = t.slice(i + 1);
        if (!src.length || !dest.length)
            return;
        const buf = Object.assign({}, root._buf);
        buf[src] = dest;
        root._buf = buf;
        flush.restart();
    }

    function _flush() {
        const buf = root._buf;
        if (!buf || Object.keys(buf).length === 0)
            return;
        root.map = Object.assign({}, root.map, buf);
        root._buf = ({});
        root.rev++;
    }

    Timer {
        id: flush
        interval: Motion.shortMs
        repeat: false
        onTriggered: root._flush()
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: (line) => root._ingest(line)
        }
        onExited: root._flush()
    }
}
