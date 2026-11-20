// Mode, owner, and group for one path. Refuses protected paths and
// a chmod when this account does not own the file.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var info: ({})
    property bool busy: false
    property string _out: ""
    property string _kind: ""
    property var _queue: []
    property string _editPath: ""
    property string _editName: ""

    signal saved()
    signal failed(string reason)

    function load(path: string) {
        root._run(["stat", path], "stat");
    }

    function save(path: string, name: string, bits: string, owner: string) {
        const args = ["edit", path];
        if (name.length)
            args.push("--name", name);
        if (bits.length)
            args.push("--mode", bits);
        if (owner.length)
            args.push("--owner", owner);
        root._editPath = String(path || "");
        root._editName = String(name || "");
        if (args.length > 2)
            root._run(args, "save");
    }

    function saveMode(path: string, bits: string) {
        root._run(["chmod", path, bits], "save");
    }

    function saveGroup(path: string, group: string) {
        root._run(["chgrp", path, group], "save");
    }

    function saveOwner(path: string, user: string) {
        root._run(["chown", path, user], "save");
    }

    function _run(args: var, kind: string) {
        const q = root._queue.slice();
        q.push({ args: args, kind: kind });
        root._queue = q;
        root._pump();
    }

    function _pump() {
        if (proc.running || !root._queue.length)
            return;
        const q = root._queue.slice();
        const job = q.shift();
        root._queue = q;
        root._kind = job.kind;
        root._out = "";
        root.busy = true;
        proc.command = [Paths.script("files-ops.sh")].concat(job.args);
        proc.running = true;
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._out = String(this.text || "")
        }
        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.failed("refused");
            else if (root._kind === "stat") {
                try { root.info = JSON.parse(root._out || "{}"); }
                catch (e) { root.info = ({}); }
            } else {
                if (root._kind === "save")
                    root._renamed();
                root.saved();
            }
            root._pump();
        }
    }

    function _renamed() {
        let info = ({});
        try { info = JSON.parse(root._out || "{}"); } catch (e) { return; }
        const made = String(info.path || "");
        if (root._editName.length && root._editPath.charAt(0) === "/" && made.charAt(0) === "/" && made !== root._editPath)
            FilesPlaces.renameOne(root._editPath, made);
    }
}
