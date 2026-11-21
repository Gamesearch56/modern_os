pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// The Texteditor's only door to the disk: scripts/editor-io.sh. Jobs run
// one at a time and in order, so a save always lands before the load,
// trash, or quit that was asked for after it. Every job answers with one
// JSON object; a helper that dies or prints nothing answers "failed".
Singleton {
    id: root

    property var _queue: []
    property var _job: null
    readonly property bool busy: root._job !== null || root._queue.length > 0

    function run(args: var, input: var, done: var) {
        const q = root._queue.slice();
        q.push({
            args: args,
            input: input === undefined || input === null ? null : String(input),
            done: done || null
        });
        root._queue = q;
        root._pump();
    }

    function _pump() {
        if (root._job || root._queue.length === 0)
            return;
        const q = root._queue.slice();
        root._job = q.shift();
        root._queue = q;
        proc.stdinEnabled = root._job.input !== null;
        proc.command = [Paths.script("editor-io.sh")].concat(root._job.args);
        proc.running = true;
    }

    function _parse(raw: string): var {
        const lines = String(raw || "").trim().split("\n");
        try {
            const out = JSON.parse(lines[lines.length - 1] || "");
            return out && typeof out === "object" ? out : null;
        } catch (e) {
            return null;
        }
    }

    function _finish(raw: string, code: int) {
        const job = root._job;
        root._job = null;
        let out = root._parse(raw);
        if (!out) {
            Logger.warn("EditorIo", "editor-io " + String(job?.args?.[0] || "") + " exited " + code + " without an answer");
            out = { ok: false, error: "failed" };
        } else if (!out.ok) {
            Logger.info("EditorIo", String(job?.args?.[0] || "") + ": " + String(out.error || "failed"));
        }
        if (job && job.done) {
            try {
                job.done(out);
            } catch (e) {
                Logger.error("EditorIo", String(e));
            }
        }
        Qt.callLater(root._pump);
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            id: collected
        }
        onStarted: {
            const job = root._job;
            if (job && job.input !== null) {
                proc.write(job.input);
                proc.stdinEnabled = false;
            }
        }
        onExited: (code) => root._finish(collected.text, code)
    }
}
