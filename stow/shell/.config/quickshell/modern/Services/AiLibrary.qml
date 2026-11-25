// Ollama library search, pull, and remove for Settings. One name at a time.
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property var results: []
    property bool searching: false
    property bool ready: false
    property bool failed: false
    property string busyName: ""
    property string jobAction: ""
    property string jobName: ""
    property string jobLog: ""
    property string jobState: ""
    property int _epoch: 0
    property var fit: ({})
    property var tags: ({})
    property int _tagEpoch: 0
    property real ramBytes: 0
    property real vramBytes: 0
    property int _fitEpoch: 0
    property int _mutateEpoch: 0
    signal finished(string action, string name, bool ok)

    Component.onCompleted: memProc.running = true

    function rate(names) {
        const epoch = ++root._fitEpoch;
        const argv = [
            Paths.script("ollama-fit.sh"),
            String(Math.round(root.ramBytes)),
            String(Math.round(root.vramBytes))
        ];
        const list = names || [];
        for (let i = 0; i < list.length; i++) {
            const n = String(list[i] || "");
            if (n.length)
                argv.push(n);
        }
        if (argv.length < 4) {
            root.fit = ({});
            return;
        }
        fitProc.running = false;
        Qt.callLater(() => {
            if (epoch !== root._fitEpoch)
                return;
            fitProc.epoch = epoch;
            fitProc.command = argv;
            fitProc.running = true;
        });
    }

    function _takeMemory(text: string) {
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const tab = lines[i].indexOf("\t");
            if (tab < 0)
                continue;
            const key = lines[i].slice(0, tab);
            const n = Number(lines[i].slice(tab + 1));
            if (!(n >= 0))
                continue;
            if (key === "ramBytes")
                root.ramBytes = n;
            else if (key === "vramBytes")
                root.vramBytes = n;
        }
    }

    function search(query: string) {
        const epoch = ++root._epoch;
        searchProc.running = false;
        root.searching = true;
        root.failed = false;
        Qt.callLater(() => {
            if (epoch !== root._epoch)
                return;
            searchProc.epoch = epoch;
            searchProc.command = [Paths.script("ollama-library.sh"), "search", String(query || "")];
            searchProc.running = true;
        });
    }

    function loadTags(family: string) {
        const f = String(family || "").split(":")[0];
        if (!f.length || root.tags[f])
            return;
        const epoch = ++root._tagEpoch;
        tagsProc.running = false;
        Qt.callLater(() => {
            if (epoch !== root._tagEpoch)
                return;
            tagsProc.epoch = epoch;
            tagsProc.family = f;
            tagsProc.command = [Paths.script("ollama-library.sh"), "tags", f];
            tagsProc.running = true;
        });
    }

    function pull(name: string) {
        root._mutate("pull", name);
    }

    function remove(name: string) {
        const cur = String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "");
        const n = String(name || "").replace(/:latest$/, "");
        if (!n.length || n === cur)
            return;
        root._mutate("remove", n);
    }

    function _mutate(action: string, name: string) {
        const n = String(name || "");
        if (!n.length || root.busyName.length)
            return;
        // command and running in one turn starts the previous (empty)
        // command, which never exits, so the button spins forever.
        const epoch = ++root._mutateEpoch;
        root.busyName = n;
        root.failed = false;
        root.jobAction = action;
        root.jobName = n;
        root.jobLog = "";
        root.jobState = "run";
        mutateProc.running = false;
        mutateProc.action = action;
        mutateProc.modelName = n;
        mutateProc.command = [Paths.script("ollama-library.sh"), action, n];
        Qt.callLater(() => {
            if (epoch !== root._mutateEpoch)
                return;
            mutateProc.running = true;
            mutateWatch.epoch = epoch;
            mutateWatch.restart();
        });
    }

    function _mutateDone(ok: bool) {
        if (!root.busyName.length)
            return;
        const action = mutateProc.action;
        const name = mutateProc.modelName;
        root.busyName = "";
        root.jobState = ok ? "ok" : "fail";
        if (!ok)
            Logger.warn("AiLibrary", action + " failed for " + name);
        root.finished(action, name, ok);
    }

    function dismissJob() {
        if (root.jobState === "run")
            return;
        root.jobState = "";
        root.jobLog = "";
        root.jobName = "";
        root.jobAction = "";
    }

    function _append(chunk: string) {
        const bits = String(chunk || "").replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "").split(/\r|\n/);
        let next = root.jobLog;
        for (let i = 0; i < bits.length; i++) {
            const line = bits[i].trim();
            if (!line.length)
                continue;
            next += line + "\n";
        }
        if (next.length > 32768)
            next = next.substring(next.length - 32768);
        root.jobLog = next;
    }

    Process {
        id: searchProc
        property int epoch: 0
        running: false
        stdout: StdioCollector { id: searchOut }
        onExited: (code) => {
            if (searchProc.epoch !== root._epoch)
                return;
            root.searching = false;
            root.ready = true;
            if (code !== 0) {
                root.failed = true;
                root.results = [];
                return;
            }
            try {
                const parsed = JSON.parse(String(searchOut.text || "").trim() || "[]");
                root.results = Array.isArray(parsed) ? parsed : [];
            } catch (e) {
                root.failed = true;
                root.results = [];
            }
        }
    }

    Process {
        id: mutateProc
        property string action: ""
        property string modelName: ""
        running: false
        // Pull prints a progress line until something reads it. Keep the
        // lines out of a growing string so a large download cannot stall.
        stdout: SplitParser { onRead: line => root._append(line) }
        stderr: SplitParser { onRead: line => root._append(line) }
        onExited: (code) => root._mutateDone(code === 0)
    }

    // A start that never launches does not emit exited. If it is still
    // idle after this, the button would spin with no download behind it.
    Timer {
        id: mutateWatch
        interval: Motion.durationMedium
        repeat: false
        property int epoch: 0
        onTriggered: {
            if (epoch !== root._mutateEpoch || !root.busyName.length)
                return;
            if (!mutateProc.running)
                root._mutateDone(false);
        }
    }

    Process {
        id: tagsProc
        property int epoch: 0
        property string family: ""
        running: false
        stdout: StdioCollector { id: tagsOut }
        onExited: (code) => {
            if (tagsProc.epoch !== root._tagEpoch)
                return;
            let rows = [];
            if (code === 0) {
                try {
                    const parsed = JSON.parse(String(tagsOut.text || "").trim() || "[]");
                    rows = Array.isArray(parsed) ? parsed : [];
                } catch (e) {
                    rows = [];
                }
            }
            const next = {};
            const cur = root.tags || {};
            for (const k in cur)
                next[k] = cur[k];
            next[tagsProc.family] = rows;
            root.tags = next;
        }
    }

    Process {
        id: memProc
        command: [Paths.script("hw-memory.sh")]
        running: false
        stdout: StdioCollector { id: memOut }
        onExited: root._takeMemory(memOut.text)
    }

    Process {
        id: fitProc
        property int epoch: 0
        running: false
        stdout: StdioCollector { id: fitOut }
        onExited: (code) => {
            if (fitProc.epoch !== root._fitEpoch || code !== 0)
                return;
            try {
                const parsed = JSON.parse(String(fitOut.text || "").trim() || "{}");
                root.fit = parsed && typeof parsed === "object" ? parsed : ({});
            } catch (e) {
                root.fit = ({});
            }
        }
    }
}
