pragma Singleton
import Quickshell
import QtQuick

// Which files are in the current drag, and which folder would receive them.

Singleton {
    id: root

    property bool active: false
    property bool foreign: false
    property var paths: []
    property string drop: ""
    property int _hover: 0

    function begin(list: var) {
        root.paths = list || [];
        root.drop = "";
        root.foreign = false;
        root.active = true;
    }

    function end() {
        root.active = false;
        root.foreign = false;
        root.paths = [];
        root.drop = "";
        root._hover = 0;
    }

    // A drag from another window arrives as file URIs, not this process's list.
    function offer(drag) {
        if (root.active && !root.foreign)
            return;
        const found = root._listed(drag);
        if (!found.length)
            return;
        root.paths = found;
        root.foreign = true;
        root.active = true;
    }

    function cover() {
        root._hover += 1;
    }

    function uncover() {
        root._hover = Math.max(0, root._hover - 1);
        if (root._hover === 0 && root.foreign)
            Qt.callLater(() => { if (root._hover === 0 && root.foreign) root.end(); });
    }

    function _listed(drag): var {
        const out = [];
        const urls = (drag && drag.urls) || [];
        let lines = [];
        for (let i = 0; i < urls.length; i++)
            lines.push(String(urls[i] || ""));
        if (!lines.length && drag)
            lines = String(drag.text || "").split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            let item = String(lines[i] || "").trim();
            if (item.indexOf("file://") === 0) {
                try { item = decodeURIComponent(item.slice(7)); } catch (e) { item = item.slice(7); }
            }
            if (item.charAt(0) === "/")
                out.push(item);
        }
        return out;
    }

    function land() {
        const dest = root.drop;
        const from = (root.paths || []).slice();
        root.end();
        if (!from.length)
            return;
        if (dest === "trash") {
            FilesTrash.move(from);
            return;
        }
        if (dest.charAt(0) !== "/")
            return;
        const moving = [];
        for (let i = 0; i < from.length; i++) {
            const item = String(from[i] || "");
            if (item.charAt(0) !== "/")
                continue;
            if (item === dest || dest.indexOf(item + "/") === 0)
                continue;
            const slash = item.lastIndexOf("/");
            const parent = slash > 0 ? item.slice(0, slash) : "/";
            if (parent === dest)
                continue;
            moving.push(item);
        }
        if (moving.length)
            FilesConflict.place("move", dest, moving);
    }
}
