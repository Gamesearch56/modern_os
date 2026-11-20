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
    property var _job: null
    property string _editPath: ""
    property string _editName: ""

    signal saved()
    signal failed(string reason)

    function load(path: string) {
        root._run(["stat", path], "stat");
    }

    function _shot() {
        const info = root.info || ({});
        return {
            path: String(info.path || ""),
            bits: String(info.bits || ""),
            owner: String(info.owner || ""),
            group: String(info.group || "")
        };
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
            root._run(args, "save", { snap: root._shot(), name: name, bits: bits, owner: owner });
    }

    function saveMode(path: string, bits: string) {
        root._run(["chmod", path, bits], "save", { snap: root._shot(), bits: bits });
    }

    function saveGroup(path: string, group: string) {
        root._editPath = String(path || "");
        root._editName = "";
        root._run(["chgrp", path, group], "save", { snap: root._shot(), group: group });
    }

    function saveOwner(path: string, user: string) {
        root._run(["chown", path, user], "save", { snap: root._shot(), owner: user });
    }

    function _run(args: var, kind: string, extra: var) {
        const q = root._queue.slice();
        q.push({ args: args, kind: kind, extra: extra || null });
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
            const job = root._job;
            root._job = null;
            root.busy = false;
            if (code !== 0)
                root.failed("refused");
            else if (root._kind === "stat") {
                try { root.info = JSON.parse(root._out || "{}"); }
                catch (e) { root.info = ({}); }
            } else {
                if (root._kind === "save") {
                    root._renamed(job);
                    FilesUndo.noteAccess(job, root._out);
                }
                root.saved();
            }
            root._pump();
        }
    }

    function _renamed(job: var) {
        let info = ({});
        try { info = JSON.parse(root._out || "{}"); } catch (e) { info = ({}); }
        const extra = job && job.extra ? job.extra : ({});
        const before = extra.snap ? String(extra.snap.path || "") : root._editPath;
        const made = String(info.path || before || "");
        const name = String(extra.name || "");
        if (name.length && before.charAt(0) === "/" && made.charAt(0) === "/" && made !== before)
            FilesPlaces.renameOne(before, made);
        root._reselect(before, made);
    }

    function _reselect(before: string, after: string) {
        const next = String(after || "");
        if (next.charAt(0) !== "/")
            return;
        const old = String(before || "");
        const cur = (Files.selected || []).slice();
        let hit = false;
        for (let i = 0; i < cur.length; i++) {
            if (String(cur[i] || "") === old) {
                cur[i] = next;
                hit = true;
            }
        }
        Files.selected = hit ? cur : [next];
    }
}
