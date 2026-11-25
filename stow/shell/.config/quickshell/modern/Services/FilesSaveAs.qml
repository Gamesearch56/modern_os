pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// The name half of FilesChoose's "save" kind. submit() checks the disk,
// not the listing, so a hidden file that is not shown is still asked
// about before an app writes over it.
Singleton {
    id: root

    property string name: ""
    property bool replacing: false
    property string _target: ""

    readonly property string leaf: String(root.name || "").trim()
    readonly property bool valid: root.leaf.length > 0 && root.leaf !== "." && root.leaf !== ".." && root.leaf.indexOf("/") < 0

    function reset(start: string) {
        root.name = String(start || "");
        root.replacing = false;
        root._target = "";
    }

    function submit(folder: string) {
        const dir = String(folder || "");
        if (!root.valid || dir.charAt(0) !== "/" || probe.running)
            return;
        root._target = (dir === "/" ? "" : dir) + "/" + root.leaf;
        probe.command = ["sh", "-c", "[ -e \"$1\" ] || [ -L \"$1\" ]", "sh", root._target];
        probe.running = true;
    }

    function replace() {
        if (!root.replacing)
            return;
        root.replacing = false;
        FilesChoose.finish([root._target]);
    }

    function keep() {
        root.replacing = false;
        root._target = "";
    }

    Process {
        id: probe
        onExited: code => {
            if (!root._target.length || !FilesChoose.active)
                return;
            if (code === 0)
                root.replacing = true;
            else
                FilesChoose.finish([root._target]);
        }
    }
}
