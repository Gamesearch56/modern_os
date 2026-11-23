// Ollama presence + /api/tags. Ai.qml owns chat history.
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property var ai: null

    function refresh() {
        if (!root.ai || whichProc.running || tagsProc.running || root.ai.busy)
            return;
        whichProc.running = false;
        Qt.callLater(() => {
            if (!root.ai.busy)
                whichProc.running = true;
        });
    }

    function modelChoices(): var {
        const out = [];
        const seen = {};
        const list = (root.ai && root.ai.models) || [];
        for (let i = 0; i < list.length; i++) {
            const stem = String(list[i] || "").replace(/:latest$/, "");
            if (!stem.length || seen[stem])
                continue;
            seen[stem] = true;
            out.push({ value: stem, titleValue: stem });
        }
        const cur = String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "");
        if (cur.length > 0 && !seen[cur])
            out.unshift({ value: cur, titleValue: cur });
        return out;
    }

    function resolveModel(want: string): string {
        const w = String(want || "").replace(/:latest$/, "");
        const list = (root.ai && root.ai.models) || [];
        let family = "";
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] || "");
            if (!n.length)
                continue;
            const stem = n.replace(/:latest$/, "");
            if (stem === w || n === w || (w.length > 0 && n.indexOf(w + ":") === 0))
                return n;
            if (!family.length && w.length >= 3
                    && (stem.indexOf(w + ".") === 0 || stem.indexOf(w + "-") === 0))
                family = n;
        }
        return family;
    }

    function _parseStatus(text: string) {
        if (!root.ai)
            return;
        const raw = String(text || "");
        const brace = raw.indexOf("{");
        let names = [];
        let on = false;
        if (brace !== -1) {
            try {
                const data = JSON.parse(raw.substring(brace));
                const list = data.models || [];
                on = true;
                for (let i = 0; i < list.length; i++) {
                    const n = String(list[i].name || list[i].model || "");
                    if (n.length)
                        names.push(n);
                }
            } catch (e) {
                Logger.warn("Ai", String(e));
            }
        }
        root.ai.running = on;
        root.ai.models = names;
        root.ai.probed = true;
    }

    Process {
        id: whichProc
        // A missing ollama binary makes Quickshell warn if it is the command.
        command: ["sh", "-c", "command -v ollama >/dev/null"]
        running: false
        onExited: (code) => {
            const installed = code === 0;
            if (root.ai)
                root.ai.installed = installed;
            if (!installed) {
                if (root.ai) {
                    root.ai.running = false;
                    root.ai.models = [];
                    root.ai.probed = true;
                }
                return;
            }
            tagsProc.running = false;
            Qt.callLater(() => {
                tagsProc.running = true;
            });
        }
    }

    Process {
        id: tagsProc
        command: ["curl", "-sf", "--max-time", "1", "http://127.0.0.1:11434/api/tags"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseStatus(this.text)
        }
        onExited: (code) => {
            if (code !== 0)
                root._parseStatus("");
        }
    }

    // Same name ollama-pull.sh downloads. The assistant uses it after.
    readonly property string setupModel: "qwen3:4b"
    property bool setupBusy: false
    property bool setupFailed: false
    signal setupFinished(bool ok, string model)

    property string jobLog: ""
    property string jobState: ""
    property string jobName: ""
    readonly property string jobAction: "pull"

    function dismissJob() {
        if (root.jobState === "run")
            return;
        root.jobState = "";
        root.jobLog = "";
        root._pendingLog = "";
        root.jobName = "";
    }

    // A pull redraws the same line for every packet. Keep the latest
    // percent and paint it on a timer, so the shell stays responsive.
    property string _pendingLog: ""

    function _append(chunk: string) {
        const bits = String(chunk || "").replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "").split(/\r|\n/);
        let lines = root._pendingLog.length ? root._pendingLog.split("\n") : [];
        for (let i = 0; i < bits.length; i++) {
            const line = bits[i].trim();
            if (!line.length)
                continue;
            const progress = /^pulling\s+\S+:\s+\d+%/.test(line);
            if (progress && lines.length && /^pulling\s+\S+:\s+\d+%/.test(lines[lines.length - 1]))
                lines[lines.length - 1] = line;
            else
                lines.push(line);
        }
        if (lines.length > 12)
            lines = lines.slice(lines.length - 12);
        root._pendingLog = lines.join("\n");
        if (!logTimer.running)
            logTimer.start();
    }

    function _flush() {
        logTimer.stop();
        root.jobLog = root._pendingLog;
    }

    Timer {
        id: logTimer
        interval: Motion.mediumMs
        repeat: false
        onTriggered: root.jobLog = root._pendingLog
    }

    function startSetup() {
        if (root.setupBusy || !root.ai || !root.ai.installed)
            return;
        root.setupFailed = false;
        root.setupBusy = true;
        root.jobName = root.setupModel;
        root.jobLog = "";
        root._pendingLog = "";
        root.jobState = "run";
        if (!root.ai.running)
            root._enable();
        else
            root._pull();
    }

    function _enable() {
        enableProc.command = [Paths.script("ollama-activate.sh")];
        enableProc.running = true;
    }

    function _pull() {
        pullProc.command = [Paths.script("ollama-pull.sh")];
        pullProc.running = true;
    }

    function _setupFail() {
        root.setupBusy = false;
        root.setupFailed = true;
        root.jobState = "fail";
        root.setupFinished(false, "");
    }

    Process {
        id: enableProc
        running: false
        stdout: SplitParser { onRead: line => root._append(line) }
        stderr: SplitParser { onRead: line => root._append(line) }
        onExited: (code) => {
            root._flush();
            if (code !== 0) {
                root._setupFail();
                return;
            }
            if (root.ai)
                root.ai.refreshStatus();
            root._pull();
        }
    }

    Process {
        id: pullProc
        running: false
        stdout: SplitParser { onRead: line => root._append(line) }
        stderr: SplitParser { onRead: line => root._append(line) }
        onExited: (code) => {
            root._flush();
            if (root.ai)
                root.ai.refreshStatus();
            if (code !== 0) {
                root._setupFail();
                return;
            }
            root.setupBusy = false;
            root.setupFailed = false;
            root.jobState = "ok";
            root.setupFinished(true, root.setupModel);
        }
    }
}
