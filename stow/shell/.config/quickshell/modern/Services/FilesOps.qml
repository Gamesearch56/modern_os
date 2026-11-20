// Queues files-ops.sh so one listing cannot overlap a rename.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    signal done(string kind, int code, string out, string err)

    property var _queue: []
    property var _job: null
    // Listings are dropped when the folder changes. A rename already
    // running is left alone.
    property int _epoch: 0

    function cancelLists() {
        root._epoch += 1;
        const kept = [];
        const q = root._queue;
        for (let i = 0; i < q.length; i++) {
            if (q[i].kind !== "list")
                kept.push(q[i]);
        }
        root._queue = kept;
        if (root._job && root._job.kind === "list")
            proc.running = false;
    }

    function enqueue(args: var, kind: string) {
        const q = root._queue.slice();
        q.push({ args: args, kind: kind, epoch: kind === "list" ? root._epoch : 0 });
        root._queue = q;
        root._pump();
    }

    function _pump() {
        if (proc.running || !root._queue.length)
            return;
        const q = root._queue.slice();
        root._job = q.shift();
        root._queue = q;
        proc.command = [Paths.script("files-ops.sh")].concat(root._job.args);
        proc.running = true;
    }

    function _finish(code: int, out: string, err: string) {
        const job = root._job;
        root._job = null;
        const stale = job && job.kind === "list" && job.epoch !== root._epoch;
        if (job && !stale)
            root.done(job.kind, code, out, err);
        root._pump();
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector { id: outBuf }
        stderr: StdioCollector { id: errBuf }
        onExited: (code) => root._finish(code, String(outBuf.text || ""), String(errBuf.text || "").trim())
    }
}
