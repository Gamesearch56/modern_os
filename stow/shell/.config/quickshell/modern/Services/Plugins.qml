// User plugins under ~/.config/modern/plugins/<id>/plugin.json.
// FileView cannot glob a directory, so a Process lists plugin.json
// files and jq (or cat) loads them. Script-backed widgets expose
// command + interval; this Service owns the Process tick.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var plugins: []
    property var outputs: ({})
    property bool open: false
    property int _cursor: 0

    Process {
        id: scan
        command: ["sh", "-c", "dir=\"$HOME/.config/modern/plugins\"; [ -d \"$dir\" ] || exit 0; for f in \"$dir\"/*/plugin.json; do [ -f \"$f\" ] || continue; if command -v jq >/dev/null; then jq -c --arg d \"$(dirname \"$f\")\" '. + {dir:$d}' \"$f\"; else printf '%s\\n' \"{\\\"dir\\\":\\\"$(dirname \"$f\")\\\"}\"; fi; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parseScan(this.text)
        }
    }

    property string runningId: ""

    Process {
        id: runner
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._onRun(this.text)
        }
    }

    Timer {
        interval: 1000
        running: root.plugins.length > 0
        repeat: true
        onTriggered: root._tick()
    }

    function toggle() { root.open = !root.open; }
    function show() { root.open = true; }
    function hide() { root.open = false; }

    IpcHandler {
        target: "plugins"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        function hide() { root.hide(); }
    }

    function refresh() {
        scan.running = true;
    }

    function _parseScan(text: string) {
        const lines = text.trim().split("\n").filter(s => s.length > 0);
        const next = [];
        for (let i = 0; i < lines.length; i++) {
            try {
                const p = JSON.parse(lines[i]);
                p._due = 0;
                next.push(p);
            } catch (e) {
                Logger.warn("Plugins", "bad plugin.json: " + e);
            }
        }
        root.plugins = next;
    }

    function _tick() {
        if (root.plugins.length === 0 || runner.running)
            return;
        const now = Date.now();
        const p = root.plugins[root._cursor % root.plugins.length];
        root._cursor = root._cursor + 1;
        const interval = Number(p.interval) || 5000;
        if (!p.command || (p._due && now < p._due))
            return;
        p._due = now + interval;
        runner.command = ["sh", "-c", String(p.command)];
        root.runningId = p.id || p.dir || "plugin";
        runner.running = true;
    }

    function _onRun(text: string) {
        const id = root.runningId || "plugin";
        const next = Object.assign({}, root.outputs);
        next[id] = text.trim();
        root.outputs = next;
    }
}
