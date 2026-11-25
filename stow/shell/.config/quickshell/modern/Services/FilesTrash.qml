// This user's XDG trash. Emptying it never touches another trash.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var items: []
    property bool busy: false
    property var _queue: []
    property string _out: ""

    signal changed()
    signal failed(string reason)

    function refresh() {
        root._enqueue(["list"], "list");
    }

    function move(paths: var) {
        const list = [];
        const rows = paths || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i])
                list.push(String(rows[i]));
        }
        if (list.length)
            root._enqueue(["move"].concat(list), "mutate");
    }

    function restore(name: string) {
        root._enqueue(["restore", name], "mutate");
    }

    function empty() {
        root._enqueue(["empty"], "mutate");
    }

    function _enqueue(args: var, kind: string) {
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
        root._job = job;
        root._out = "";
        root.busy = true;
        proc.command = [Paths.script("files-trash.sh")].concat(job.args);
        proc.running = true;
    }

    property var _job: null

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._out = String(this.text || "")
        }
        onExited: (code) => {
            const job = root._job;
            root._job = null;
            root.busy = false;
            if (code !== 0)
                root.failed("refused");
            if (job && job.kind === "list" && code === 0) {
                try {
                    root.items = JSON.parse(root._out || "[]");
                } catch (e) {
                    root.items = [];
                }
            } else if (job && job.kind === "mutate") {
                if (job.args && String(job.args[0] || "") === "move")
                    FilesPlaces.drop(job.args.slice(1));
                FilesUndo.noteTrash(job.args, root._out);
                root.changed();
                root.refresh();
            }
            root._pump();
        }
    }
}
